// 이 기기(브라우저)에서 각 글을 마지막으로 본 날짜·시각을 표시한다.
// 정적 사이트라 서버는 조회를 모름 → localStorage에 페이지별로 기록.
// 표시: 이번 방문 "직전"에 본 시각(처음이면 '처음 방문'). 표시 후 현재 시각으로 갱신.
(function () {
  function fmt(ts) {
    var d = new Date(Number(ts));
    var p = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) +
      ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
  }

  function setup() {
    var article = document.querySelector('.md-content article') || document.querySelector('.md-content');
    if (!article) return;
    var h1 = article.querySelector('h1');
    var key = 'lv:' + location.pathname;
    var prev = null;
    try { prev = localStorage.getItem(key); } catch (e) { return; }

    var el = document.getElementById('last-viewed-note');
    if (!el) {
      el = document.createElement('div');
      el.id = 'last-viewed-note';
      el.style.cssText = 'font-size:.72rem;color:var(--md-default-fg-color--light);margin:.2rem 0 1rem;opacity:.85;';
      if (h1 && h1.parentNode) { h1.parentNode.insertBefore(el, h1.nextSibling); }
      else { article.insertBefore(el, article.firstChild); }
    }
    el.textContent = prev ? ('🕒 마지막으로 본 시각: ' + fmt(prev)) : '🕒 이 기기에서 처음 보는 글';

    try { localStorage.setItem(key, String(Date.now())); } catch (e) {}
  }

  // Material의 instant navigation(전체 리로드 없음)에서도 동작하도록 document$ 구독.
  if (typeof window.document$ !== 'undefined' && window.document$.subscribe) {
    window.document$.subscribe(function () { setup(); });
  } else if (document.readyState !== 'loading') {
    setup();
  } else {
    document.addEventListener('DOMContentLoaded', setup);
  }
})();
