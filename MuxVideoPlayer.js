/**
 * MuxVideoPlayer.js
 * Reusable Mux HLS video player for the Lumen web app.
 *
 * Loads @mux/mux-player web component from CDN (no build step needed).
 * Persists and restores resume position via the Supabase video_progress table.
 *
 * Usage (inside any <script type="module"> block):
 *
 *   import MuxVideoPlayer from './MuxVideoPlayer.js'
 *
 *   const player = new MuxVideoPlayer({
 *     container:  document.getElementById('player-wrap'),
 *     playbackId: 'YOUR_MUX_PLAYBACK_ID',
 *     videoId:    'intro-vinyasa',     // stable text key for video_progress
 *     title:      'Intro to Vinyasa',  // shown in player metadata
 *     db,                              // Supabase client (window.db)
 *     userId,                          // session.user.id
 *   })
 *
 *   await player.init()   // async: loads script + fetches resume position
 *   player.destroy()      // removes element, saves final position, cleans up
 */

const MUX_PLAYER_CDN = 'https://cdn.jsdelivr.net/npm/@mux/mux-player'

// Debounce interval for timeupdate → Supabase upsert (ms).
// Keeps DB writes to ~1 per 5 s while the video is playing.
const SAVE_INTERVAL_MS = 5000

// ── Script loader ──────────────────────────────────────────────────────────
// Injects the Mux CDN <script type="module"> once and resolves when the
// custom element is ready. Safe to call multiple times on the same page.

let _scriptPromise = null

function loadMuxScript() {
  if (_scriptPromise) return _scriptPromise

  _scriptPromise = new Promise((resolve) => {
    if (customElements.get('mux-player')) {
      resolve()
      return
    }
    const script = document.createElement('script')
    script.src  = MUX_PLAYER_CDN
    script.type = 'module'
    script.onload = () => {
      // Custom element registration is async after the module loads.
      // Poll until the element is defined (typically < 100 ms).
      const poll = setInterval(() => {
        if (customElements.get('mux-player')) {
          clearInterval(poll)
          resolve()
        }
      }, 50)
    }
    script.onerror = () => {
      console.error('[MuxVideoPlayer] Failed to load Mux player script from CDN.')
      resolve() // resolve anyway so callers don't hang
    }
    document.head.appendChild(script)
  })

  return _scriptPromise
}

// ── Component class ────────────────────────────────────────────────────────

export default class MuxVideoPlayer {
  /**
   * @param {object} opts
   * @param {HTMLElement} opts.container   - Element to mount the player inside
   * @param {string}      opts.playbackId  - Mux playback ID
   * @param {string}      [opts.videoId]   - Stable key for video_progress table
   * @param {string}      [opts.title]     - Video title (player metadata)
   * @param {object}      [opts.db]        - Supabase client instance
   * @param {string}      [opts.userId]    - Authenticated user UUID
   */
  constructor({ container, playbackId, videoId = null, title = '', db = null, userId = null }) {
    if (!container)  throw new Error('[MuxVideoPlayer] opts.container is required')
    if (!playbackId) throw new Error('[MuxVideoPlayer] opts.playbackId is required')

    this._container  = container
    this._playbackId = playbackId
    this._videoId    = videoId
    this._title      = title
    this._db         = db
    this._userId     = userId

    this._el         = null   // <mux-player> DOM element
    this._saveTimer  = null   // debounce handle
    this._destroyed  = false
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /**
   * Loads the Mux script, fetches any saved resume position, mounts the
   * <mux-player> element, and wires up progress-saving listeners.
   * Must be awaited before interacting with the player.
   */
  async init() {
    await loadMuxScript()

    const resumeTime = await this._fetchResumeTime()

    this._el = this._createElement(resumeTime)
    this._container.appendChild(this._el)
    this._attachListeners()
  }

  /**
   * Saves the current position one final time, removes the element, and
   * cancels all pending timers. Safe to call more than once.
   */
  async destroy() {
    if (this._destroyed) return
    this._destroyed = true

    clearTimeout(this._saveTimer)
    await this._saveProgress()

    if (this._el) {
      this._el.remove()
      this._el = null
    }
  }

  /** Current playback position in seconds (0 if not yet initialised). */
  get currentTime() {
    return Math.floor(this._el?.currentTime || 0)
  }

  /** Total video duration in seconds (0 if metadata not yet loaded). */
  get duration() {
    return Math.floor(this._el?.duration || 0)
  }

  // ── Private ────────────────────────────────────────────────────────────

  _createElement(resumeTime) {
    const el = document.createElement('mux-player')

    el.setAttribute('playback-id',            this._playbackId)
    el.setAttribute('metadata-video-title',   this._title)
    el.setAttribute('accent-color',           '#C8A96E')  // Lumen gold
    el.setAttribute('start-time',             resumeTime)
    el.setAttribute('preload',                'metadata')

    // Responsive, rounded, matches dark theme
    Object.assign(el.style, {
      width:        '100%',
      aspectRatio:  '16 / 9',
      borderRadius: '12px',
      overflow:     'hidden',
      background:   '#080807',
      display:      'block',
    })

    return el
  }

  _attachListeners() {
    if (!this._canSave()) return

    // Debounced save on every timeupdate tick
    const onTimeUpdate = () => {
      clearTimeout(this._saveTimer)
      this._saveTimer = setTimeout(() => this._saveProgress(), SAVE_INTERVAL_MS)
    }

    // Immediate save on pause, end, or page hide
    const onImmediate = () => this._saveProgress()

    this._el.addEventListener('timeupdate',       onTimeUpdate)
    this._el.addEventListener('pause',            onImmediate)
    this._el.addEventListener('ended',            onImmediate)
    document.addEventListener('visibilitychange', onImmediate)

    // Store references so destroy() could remove them if needed
    this._onTimeUpdate = onTimeUpdate
    this._onImmediate  = onImmediate
  }

  async _fetchResumeTime() {
    if (!this._canSave()) return 0

    try {
      const { data, error } = await this._db
        .from('video_progress')
        .select('current_time')
        .eq('user_id', this._userId)
        .eq('video_id', this._videoId)
        .maybeSingle()

      if (error) {
        console.warn('[MuxVideoPlayer] Could not fetch resume position:', error.message)
        return 0
      }
      return data?.current_time || 0
    } catch (e) {
      console.warn('[MuxVideoPlayer] Resume fetch threw:', e)
      return 0
    }
  }

  async _saveProgress() {
    if (!this._canSave() || !this._el || this._el.currentTime <= 0) return

    const currentTime   = Math.floor(this._el.currentTime)
    const totalDuration = this._el.duration > 0
      ? Math.floor(this._el.duration)
      : null

    try {
      const { error } = await this._db
        .from('video_progress')
        .upsert(
          {
            user_id:        this._userId,
            video_id:       this._videoId,
            current_time:   currentTime,
            total_duration: totalDuration,
          },
          { onConflict: 'user_id,video_id' }
        )

      if (error) {
        console.warn('[MuxVideoPlayer] Progress save failed:', error.message)
      }
    } catch (e) {
      console.warn('[MuxVideoPlayer] Progress save threw:', e)
    }
  }

  /** Returns true only when all prerequisites for Supabase writes are present. */
  _canSave() {
    return !!(this._db && this._userId && this._videoId)
  }
}
