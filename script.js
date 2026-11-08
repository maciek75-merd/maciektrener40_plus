(() => {
  'use strict';

  const header = document.querySelector('.header');
  const nav = document.getElementById('nav');
  const burger = document.getElementById('burger');
  const desktop = window.matchMedia('(min-width: 1200px)');

  /* ---------- Sticky header: tło po przewinięciu ---------- */
  const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 20);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  /* ---------- Menu mobilne ---------- */
  const setMenu = (open) => {
    nav.classList.toggle('is-open', open);
    burger.setAttribute('aria-expanded', String(open));
    burger.setAttribute('aria-label', open ? 'Zamknij menu' : 'Otwórz menu');
    document.body.classList.toggle('menu-open', open);
  };
  burger.addEventListener('click', () => setMenu(!nav.classList.contains('is-open')));
  nav.addEventListener('click', (e) => { if (e.target.closest('a')) setMenu(false); });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && nav.classList.contains('is-open')) { setMenu(false); burger.focus(); }
  });
  desktop.addEventListener('change', (e) => { if (e.matches) setMenu(false); });

  /* ---------- Aktywny link w nawigacji ---------- */
  const links = [...document.querySelectorAll('.nav__link')];
  const sections = links.map((l) => document.querySelector(l.getAttribute('href'))).filter(Boolean);
  if ('IntersectionObserver' in window) {
    const spy = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        links.forEach((l) => l.classList.toggle('is-active', l.getAttribute('href') === '#' + entry.target.id));
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    sections.forEach((s) => spy.observe(s));
  }

  /* ---------- FAQ: akordeon ---------- */
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const toggleFaq = (btn, open) => {
    const panel = document.getElementById(btn.getAttribute('aria-controls'));
    btn.setAttribute('aria-expanded', String(open));

    if (reduceMotion) { panel.hidden = !open; return; }

    if (open) {
      panel.hidden = false;
      const h = panel.scrollHeight;
      panel.style.height = '0px';
      requestAnimationFrame(() => { panel.style.height = h + 'px'; });
    } else {
      panel.style.height = panel.scrollHeight + 'px';
      requestAnimationFrame(() => { panel.style.height = '0px'; });
    }
    panel.addEventListener('transitionend', function done() {
      panel.removeEventListener('transitionend', done);
      if (btn.getAttribute('aria-expanded') === 'true') panel.style.height = '';
      else panel.hidden = true;
    });
  };

  document.querySelectorAll('.faq__q button').forEach((btn) => {
    btn.addEventListener('click', () => {
      const willOpen = btn.getAttribute('aria-expanded') !== 'true';
      // zamknij pozostałe
      document.querySelectorAll('.faq__q button[aria-expanded="true"]').forEach((other) => {
        if (other !== btn) toggleFaq(other, false);
      });
      toggleFaq(btn, willOpen);
    });
  });

  /* ---------- Zakładki: plany treningowe ---------- */
  document.querySelectorAll('[role="tablist"]').forEach((list) => {
    const tabs = [...list.querySelectorAll('[role="tab"]')];
    const select = (tab, focus) => {
      tabs.forEach((t) => {
        const on = t === tab;
        t.setAttribute('aria-selected', String(on));
        t.tabIndex = on ? 0 : -1;
        document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
      });
      if (focus) tab.focus();
    };
    tabs.forEach((tab, i) => {
      tab.addEventListener('click', () => select(tab));
      tab.addEventListener('keydown', (e) => {
        const map = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: tabs.length - 1 };
        if (!(e.key in map)) return;
        e.preventDefault();
        select(tabs[(map[e.key] + tabs.length) % tabs.length], true);
      });
    });
    select(tabs.find((t) => t.getAttribute('aria-selected') === 'true') || tabs[0]);
  });

  /* ---------- Przyciski "Zapisz się" → wybór usługi w formularzu ---------- */
  const serviceSelect = document.getElementById('service');
  document.querySelectorAll('[data-service]').forEach((btn) => {
    btn.addEventListener('click', () => { serviceSelect.value = btn.dataset.service; });
  });

  /* ---------- Formularz: walidacja po stronie klienta ---------- */
  const form = document.getElementById('contact-form');
  const success = document.getElementById('form-success');

  const rules = {
    name: (v) => v.trim().length >= 2 || 'Podaj imię i nazwisko.',
    email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim()) || 'Podaj poprawny adres e-mail.',
    phone: (v) => !v.trim() || /^[+\d\s()-]{9,}$/.test(v.trim()) || 'Podaj poprawny numer telefonu.',
    message: (v) => v.trim().length >= 10 || 'Napisz kilka słów o swoim celu (min. 10 znaków).',
    consent: (_, el) => el.checked || 'Zgoda jest wymagana, abym mógł odpowiedzieć.'
  };

  const validateField = (el) => {
    const rule = rules[el.name];
    if (!rule) return true;
    const result = rule(el.value, el);
    const error = el.closest('.form__row').querySelector('.form__error');
    const ok = result === true;
    el.classList.toggle('is-invalid', !ok);
    el.setAttribute('aria-invalid', String(!ok));
    if (error) error.textContent = ok ? '' : result;
    return ok;
  };

  form.addEventListener('blur', (e) => { if (e.target.name in rules) validateField(e.target); }, true);
  form.addEventListener('input', (e) => { if (e.target.classList.contains('is-invalid')) validateField(e.target); });
  form.addEventListener('change', (e) => { if (e.target.type === 'checkbox') validateField(e.target); });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fields = [...form.elements].filter((el) => el.name in rules);
    const valid = fields.map(validateField).every(Boolean);
    if (!valid) { form.querySelector('.is-invalid')?.focus(); return; }

    const btn = form.querySelector('[type="submit"]');
    btn.disabled = true;
    btn.textContent = 'Wysyłanie…';

    // TODO: podłącz backend, np. Formspree:
    // await fetch('https://formspree.io/f/TWOJ_ID', { method: 'POST', body: new FormData(form), headers: { Accept: 'application/json' } });
    await new Promise((r) => setTimeout(r, 700));

    form.reset();
    btn.disabled = false;
    btn.textContent = 'Wyślij zapytanie';
    success.hidden = false;
    setTimeout(() => { success.hidden = true; }, 8000);
  });

  /* ---------- Animacja pojawiania się sekcji ---------- */
  if ('IntersectionObserver' in window && !reduceMotion) {
    const targets = document.querySelectorAll('.section__head, .about__photo, .about__text, .cards, .plans__text, .tabs, .plan-grid, .recipes, .steps, .results, .faq, .contact__info, .form');
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) { entry.target.classList.add('is-visible'); io.unobserve(entry.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    targets.forEach((el, i) => {
      el.classList.add('reveal');
      el.style.transitionDelay = (i % 4) * 70 + 'ms';
      io.observe(el);
    });
  }

  /* ---------- Rok w stopce ---------- */
  document.getElementById('year').textContent = new Date().getFullYear();
})();
