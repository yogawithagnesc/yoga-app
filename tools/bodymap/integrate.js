// M3b integration: injects the generated compact (unlabeled, small) and
// full-screen (labeled) SVG markup into the COMPACT_MARKUP/FULL_MARKUP
// placeholder objects in lumen-log-practice-3d.html. The surrounding CSS,
// modal HTML, and interaction JS (buildSvg/attachSvgHandlers/svgTap/
// applyFeeling/etc.) were hand-authored directly in the page and are not
// touched by this script — only the two data objects are replaced.
const fs = require('fs');
const PAGE = '/home/user/yoga-app/lumen-log-practice-3d.html';

const read = (f) => fs.readFileSync(`${__dirname}/${f}`, 'utf8');

const compactFront = read('front2_markup.txt');
const compactBack  = read('back2_markup.txt');
const fullFront    = read('front2_full_markup.txt');
const fullBack     = read('back2_full_markup.txt');

let html = fs.readFileSync(PAGE, 'utf8');

const start = html.indexOf('const COMPACT_MARKUP = {');
const endMarker = 'function buildSvg(containerId, view) {';
const endIdx = html.indexOf(endMarker);
if (start < 0 || endIdx < 0) throw new Error('COMPACT_MARKUP/FULL_MARKUP block markers not found — did the surrounding JS get renamed?');

const newBlock = `const COMPACT_MARKUP = {
  front: \`${compactFront}\`,
  back: \`${compactBack}\`,
};
const FULL_MARKUP = {
  front: \`${fullFront}\`,
  back: \`${fullBack}\`,
};

`;

html = html.slice(0, start) + newBlock + html.slice(endIdx);
fs.writeFileSync(PAGE, html);
console.log('integrated: compact front', compactFront.length, 'chars, back', compactBack.length,
            '| full front', fullFront.length, ', back', fullBack.length);
