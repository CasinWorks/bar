import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import { useAuth } from '../context/AuthContext';
import './landing.css';

gsap.registerPlugin(ScrollTrigger);

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

export default function LandingPage() {
  const rootRef = useRef(null);
  const lenisRef = useRef(null);
  const mvpClicksRef = useRef(0);
  const mvpClickTimerRef = useRef(null);
  const { profile } = useAuth();

  useEffect(() => {
    document.documentElement.classList.add('lp-scroll-lock');
    return () => document.documentElement.classList.remove('lp-scroll-lock');
  }, []);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return undefined;

    const reduced = prefersReducedMotion();
    let lenis = null;
    let tickerFn = null;

    if (!reduced) {
      lenis = new Lenis({
        lerp: 0.08,
        duration: 0.9,
        easing: (t) => 1 - Math.pow(1 - t, 3),
        smoothWheel: true,
        syncTouch: true,
        touchMultiplier: 1.05,
        wheelMultiplier: 0.72,
        autoRaf: false,
      });
      lenisRef.current = lenis;
      document.documentElement.classList.add('lenis');

      lenis.on('scroll', ScrollTrigger.update);
      tickerFn = (time) => {
        lenis.raf(time * 1000);
      };
      gsap.ticker.add(tickerFn);
      gsap.ticker.lagSmoothing(0);
    }

    const scrub = reduced ? false : 0.35;
    const ctx = gsap.context(() => {
      if (reduced) {
        gsap.set(
          [
            '.lp-hero-copy',
            '.lp-emblem',
            '.lp-claw',
            '.lp-float-card',
            '.lp-dash-preview',
            '.lp-beat-stage',
            '.lp-orb',
            '.lp-hero-stats',
            '.lp-section-head',
            '.lp-feature-card',
            '.lp-story-line',
            '.lp-finale-inner',
          ],
          { clearProps: 'all', opacity: 1, y: 0, scale: 1, rotateX: 0, rotateY: 0, filter: 'none' },
        );
        return;
      }

      const heroTl = gsap.timeline({
        scrollTrigger: {
          trigger: '.lp-hero-pin',
          start: 'top top',
          end: '+=140%',
          scrub,
          pin: true,
          anticipatePin: 1,
          fastScrollEnd: false,
          invalidateOnRefresh: true,
        },
      });

      heroTl
        .fromTo('.lp-hero-copy', { y: 36, opacity: 0.6 }, { y: 0, opacity: 1, ease: 'none' }, 0)
        .fromTo(
          '.lp-emblem',
          { scale: 0.78, rotateY: -22, rotateX: 10, opacity: 0.55 },
          { scale: 1.06, rotateY: 6, rotateX: -3, opacity: 1, ease: 'none' },
          0,
        )
        .fromTo('.lp-claw', { scaleY: 0.45, opacity: 0 }, { scaleY: 1, opacity: 1, ease: 'none' }, 0.04)
        .fromTo(
          '.lp-float-card',
          { y: 64, opacity: 0, rotateZ: -5 },
          { y: 0, opacity: 1, rotateZ: 0, ease: 'none' },
          0.12,
        )
        .fromTo(
          '.lp-dash-preview',
          { y: 96, opacity: 0, scale: 0.9, rotateY: 14 },
          { y: 0, opacity: 1, scale: 1, rotateY: 0, ease: 'none' },
          0.22,
        )
        .fromTo(
          '.lp-beat-stage',
          { y: 72, opacity: 0, scale: 0.92 },
          { y: 0, opacity: 1, scale: 1, ease: 'none' },
          0.18,
        )
        .fromTo('.lp-orb', { opacity: 0.25, scale: 0.7 }, { opacity: 0.9, scale: 1.1, ease: 'none' }, 0)
        .to('.lp-hero-stats', { opacity: 1, y: 0, ease: 'none' }, 0.3)
        .to('.lp-scroll-hint', { opacity: 0, y: -12, ease: 'none' }, 0.15);

      gsap.from('.lp-hero-stats .lp-stat', {
        scrollTrigger: {
          trigger: '.lp-hero-pin',
          start: 'top top',
          end: '+=70%',
          scrub,
        },
        y: 22,
        opacity: 0,
        stagger: 0.1,
      });

      gsap.from('.lp-section-head', {
        scrollTrigger: {
          trigger: '.lp-command',
          start: 'top 78%',
          end: 'top 48%',
          scrub,
        },
        y: 48,
        opacity: 0,
      });

      gsap.from('.lp-feature-card', {
        scrollTrigger: {
          trigger: '.lp-features',
          start: 'top 82%',
          end: 'top 42%',
          scrub,
        },
        y: 72,
        opacity: 0,
        rotateX: 12,
        stagger: 0.12,
        transformOrigin: 'center bottom',
      });

      const storyTl = gsap.timeline({
        scrollTrigger: {
          trigger: '.lp-story-pin',
          start: 'top top',
          end: '+=110%',
          scrub,
          pin: true,
          anticipatePin: 1,
          fastScrollEnd: false,
          invalidateOnRefresh: true,
        },
      });

      storyTl
        .fromTo('.lp-story-line-1', { opacity: 0.18, y: 24 }, { opacity: 1, y: 0 })
        .to('.lp-story-line-1', { opacity: 0.22, y: -16 }, '+=0.18')
        .fromTo('.lp-story-line-2', { opacity: 0, y: 32 }, { opacity: 1, y: 0 }, '<0.08')
        .to('.lp-story-line-2', { opacity: 0.28, y: -12 }, '+=0.2')
        .fromTo('.lp-story-line-3', { opacity: 0, y: 32 }, { opacity: 1, y: 0 }, '<0.08');

      gsap.from('.lp-finale-inner', {
        scrollTrigger: {
          trigger: '.lp-finale',
          start: 'top 72%',
          end: 'top 36%',
          scrub,
        },
        scale: 0.94,
        opacity: 0,
        filter: 'blur(6px)',
      });

      gsap.to('.lp-glow-a', {
        scrollTrigger: {
          trigger: root,
          scrub: 0.8,
          start: 'top top',
          end: 'bottom bottom',
        },
        y: -140,
        ease: 'none',
      });
      gsap.to('.lp-glow-b', {
        scrollTrigger: {
          trigger: root,
          scrub: 0.8,
          start: 'top top',
          end: 'bottom bottom',
        },
        y: 160,
        ease: 'none',
      });

      ScrollTrigger.refresh();
    }, root);

    const onResize = () => {
      lenis?.resize();
      ScrollTrigger.refresh();
    };
    window.addEventListener('resize', onResize);

    return () => {
      window.removeEventListener('resize', onResize);
      ctx.revert();
      if (tickerFn) gsap.ticker.remove(tickerFn);
      gsap.ticker.lagSmoothing(500, 33);
      lenis?.destroy();
      lenisRef.current = null;
      document.documentElement.classList.remove('lenis');
    };
  }, []);

  function scrollToSection(e, id = 'suite') {
    e.preventDefault();
    const target = document.getElementById(id);
    if (!target) return;
    if (lenisRef.current) {
      lenisRef.current.scrollTo(target, { offset: -24, duration: 1.35 });
    } else {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  function handleMvpClick() {
    mvpClicksRef.current += 1;
    window.clearTimeout(mvpClickTimerRef.current);
    mvpClickTimerRef.current = window.setTimeout(() => {
      mvpClicksRef.current = 0;
    }, 1800);

    if (mvpClicksRef.current >= 5) {
      window.clearTimeout(mvpClickTimerRef.current);
      window.location.href = profile ? '/app' : '/login';
    }
  }

  return (
    <div className="lp" ref={rootRef}>
      <div className="lp-glow lp-glow-a" aria-hidden />
      <div className="lp-glow lp-glow-b" aria-hidden />

      <header className="lp-nav">
        <div className="lp-brand">
          <span className="lp-mark" aria-hidden>
            虎
          </span>
          <span>BLIND TIGER</span>
        </div>
        <nav className="lp-nav-links">
          <a href="#suite" onClick={(e) => scrollToSection(e, 'suite')}>
            THE CLUB
          </a>
          <a href="#membership" onClick={(e) => scrollToSection(e, 'membership')}>
            MEMBERSHIP
          </a>
        </nav>
      </header>

      <section className="lp-hero-pin">
        <div className="lp-hero">
          <div className="lp-hero-copy">
            <p className="lp-eyebrow">私 人 会 所 · SECRET CELLAR</p>
            <h1 className="lp-title">
              The club behind
              <br />
              the velvet door.
            </h1>
            <p className="lp-lede">
              Blind Tiger is a time-based speakeasy: guests buy minutes at the house,
              spend them on the floor, and feel every second move with the music.
            </p>
            <div className="lp-cta-row">
              <a className="lp-btn lp-btn-primary" href="#suite" onClick={(e) => scrollToSection(e, 'suite')}>
                ENTER THE CLUB
              </a>
              <a className="lp-btn lp-btn-ghost" href="#suite" onClick={(e) => scrollToSection(e, 'suite')}>
                FEEL THE NIGHT
              </a>
            </div>
            <div className="lp-hero-stats">
              <div className="lp-stat">
                <strong>₱101K</strong>
                <span>HOUSE LOADS</span>
              </div>
              <div className="lp-stat">
                <strong>6060m</strong>
                <span>MINUTES POURED</span>
              </div>
              <div className="lp-stat">
                <strong>LIVE</strong>
                <span>FLOOR PULSE</span>
              </div>
            </div>
          </div>

          <div className="lp-hero-stage" aria-hidden>
            <div className="lp-orb" />
            <div className="lp-emblem">
              <span className="lp-tiger">虎</span>
              <div className="lp-claw">
                <i />
                <i />
                <i />
              </div>
            </div>
            <div className="lp-float-card">
              <span className="lp-live-dot" />
              LIVE FLOOR · TIME RUNNING
              <small>Minutes, music, tables, and social play moving together</small>
            </div>
            <div className="lp-beat-stage">
              <div className="lp-beat-title">MAIN ROOM SIGNAL</div>
              <div className="lp-beat-bars">
                {Array.from({ length: 18 }).map((_, i) => (
                  <i key={i} style={{ '--i': i }} />
                ))}
              </div>
              <div className="lp-wave-lines">
                <span />
                <span />
                <span />
              </div>
            </div>
            <div className="lp-dash-preview">
              <div className="lp-dash-side">
                <b>BLIND TIGER</b>
                <span>Tonight</span>
                <span>Time Wallet</span>
                <span>Pass The Glass</span>
                <span>Play</span>
                <span>Guest List</span>
                <span>Cellar</span>
              </div>
              <div className="lp-dash-main">
                <h3>Inside The Club</h3>
                <div className="lp-dash-grid">
                  <div>
                    <em>421h</em>
                    <small>time left</small>
                  </div>
                  <div>
                    <em>08</em>
                    <small>tables</small>
                  </div>
                  <div>
                    <em>PLAY</em>
                    <small>social</small>
                  </div>
                  <div>
                    <em>BAR</em>
                    <small>open</small>
                  </div>
                </div>
                <p>Time as currency · music as signal · the house in your pocket</p>
              </div>
            </div>
          </div>
        </div>
        <p className="lp-scroll-hint">
          <span className="lp-scroll-hint-line" aria-hidden />
          Scroll to enter the club
        </p>
      </section>

      <section className="lp-story-pin">
        <div className="lp-story">
          <p className="lp-story-line lp-story-line-1">A speakeasy,</p>
          <p className="lp-story-line lp-story-line-2">retracked for the night.</p>
          <p className="lp-story-line lp-story-line-3">
            Time as currency. Cash at the desk.
            <br />
            Guests enter with minutes, spend them with friends, and leave with a story.
          </p>
        </div>
      </section>

      <section className="lp-command" id="suite">
        <div className="lp-section-head">
          <p className="lp-eyebrow">THE CLUB / 夜间体验</p>
          <h2>Not just a bar. A timed social ritual.</h2>
          <p>
            The guest experience is the product: a velvet-room economy where minutes unlock entry,
            play, toasts, tips, rooms, and the feeling that the night is alive.
          </p>
        </div>

        <div className="lp-features">
          <article className="lp-feature-card">
            <span className="lp-num">01</span>
            <div className="lp-ico">♬</div>
            <h3>Time becomes the tab</h3>
            <p>
              Guests buy minutes through the house, then watch their balance move through the
              club like a private meter.
            </p>
          </article>
          <article className="lp-feature-card lp-feature-card--hot">
            <span className="lp-num">02</span>
            <div className="lp-ico">◌</div>
            <h3>Social play in the room</h3>
            <p>
              Toast to Meet, Pass the Glass, Duo Beat, and private rooms turn strangers into a
              story without turning the club into a dating app.
            </p>
          </article>
          <article className="lp-feature-card">
            <span className="lp-num">03</span>
            <div className="lp-ico">虎</div>
            <h3>The house controls the night</h3>
            <p>
              Door scans, cash loads, staff tips, and guest status stay behind the curtain while
              the floor feels effortless.
            </p>
          </article>
        </div>
      </section>

      <section className="lp-finale" id="membership">
        <div className="lp-finale-inner">
          <p className="lp-eyebrow">MEMBERSHIP</p>
          <h2>Bring minutes. Leave later.</h2>
          <p>
            The Blind Tiger starts at the door: cash at the desk, time in your pocket,
            music in the walls, and a room built for one more round.
          </p>
          <a className="lp-btn lp-btn-primary" href="#suite" onClick={(e) => scrollToSection(e, 'suite')}>
            DISCOVER THE NIGHT
          </a>
        </div>
      </section>

      <footer className="lp-foot">
        <span>
          © Blind Tiger Social Club ·{' '}
          <button className="lp-mvp-trigger" type="button" onClick={handleMvpClick}>
            MVP
          </button>
        </span>
        <span>Time as currency</span>
      </footer>
    </div>
  );
}
