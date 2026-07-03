// Client-side Deva/IAST -> Harvard-Kyoto (HK) auto-transcode for the primary-language
// search field. Reuses sanskrit-util (js/vendor/sanskrit-util.global.js, v0.3.0, MIT,
// IAST/Deva<->SLP1) plus the SLP1->HK map already built and used server-side by kosha
// (kosha/app/transliterate.py:_SLP1_TO_HK) -- ported here, not reinvented, per
// docs/ROADMAP_2026_2027.md Wave 2 ("do not write transcoder #63").
//
// Design note (differs from kosha's sniffer): kosha treats plain ASCII with no
// diacritics/Devanagari as SLP1 by default, because kosha is SLP1-native. csl-santam
// is HK-native -- its whole existing corpus and UI assume plain-ASCII input IS already
// Harvard-Kyoto. So here, plain ASCII is left completely untouched; only text containing
// genuine Devanagari codepoints or IAST diacritics triggers conversion. This preserves
// every existing user's behavior exactly and only adds new capability.
//
// NOT applied to the Cologne Online Tamil Lexicon (otl): its HK-like scheme differs from
// the Sanskrit one handled here (palatal n = "jn" not the Sanskrit ṅ/ñ mapping, alveolar
// n = "n2", different consonant ordering -- see docs/ARCHITECTURE.md "Encoding rationale").
// Callers must skip conversion when dictionary=otl; this module does not know about the
// dictionary selector.
(function (global) {
  'use strict';

  var DEVA_RE = /[ऀ-ॿ]/;
  var IAST_DIACRITICS_RE = /[āīūṛṝḷḹṃṁḥṅñṭḍṇśṣḻĀĪŪṚṜḶḸṂṀḤṄÑṬḌṆŚṢḺ]/;

  // Ported verbatim from kosha/app/transliterate.py's _SLP1_TO_HK (sanskrit-lexicon org,
  // MIT). Standard SLP1->HK correspondence; letters absent from this map are identical
  // in both schemes (a i u e o k g c j t d n p b m y r l v s h ...).
  var SLP1_TO_HK = {
    A: 'A', I: 'I', U: 'U', f: 'R', F: 'RR', x: 'lR', X: 'lRR',
    E: 'ai', O: 'au', M: 'M', H: 'H',
    K: 'kh', G: 'gh', N: 'G', C: 'ch', J: 'jh', Y: 'J',
    w: 'T', W: 'Th', q: 'D', Q: 'Dh', R: 'N',
    T: 'th', D: 'dh', P: 'ph', B: 'bh',
    S: 'z', z: 'S', L: 'L'
  };

  function slp1ToHk(slp1) {
    var out = '';
    for (var i = 0; i < slp1.length; i++) {
      var ch = slp1.charAt(i);
      out += SLP1_TO_HK.hasOwnProperty(ch) ? SLP1_TO_HK[ch] : ch;
    }
    return out;
  }

  function detectScheme(text) {
    if (DEVA_RE.test(text)) return 'deva';
    if (IAST_DIACRITICS_RE.test(text)) return 'iast';
    return 'hk'; // plain ASCII: assume already Harvard-Kyoto (csl-santam's native input scheme)
  }

  function toHK(text) {
    if (!text) return text;
    var su = global.SanskritUtil;
    if (!su) return text; // vendor script failed to load: no-op, never corrupt input
    var scheme = detectScheme(text);
    if (scheme === 'hk') return text;
    var slp1 = scheme === 'deva' ? su.deva_to_slp1(text) : su.to_slp1(text);
    return slp1ToHk(slp1);
  }

  global.CslSantamHkInput = { detectScheme: detectScheme, toHK: toHK, slp1ToHk: slp1ToHk };
})(typeof window !== 'undefined' ? window : this);
