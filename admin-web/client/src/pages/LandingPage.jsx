import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import { useAuth } from '../context/AuthContext';
import './landing.css';

gsap.registerPlugin(ScrollTrigger);

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function prefersFastMobileScroll() {
  return window.matchMedia('(max-width: 760px), (pointer: coarse)').matches;
}

export default function LandingPage() {
  const rootRef = useRef(null);
  const lenisRef = useRef(null);
  const mobileMenuButtonRef = useRef(null);
  const mobileNavRef = useRef(null);
  const mvpClicksRef = useRef(0);
  const mvpClickTimerRef = useRef(null);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const { profile } = useAuth();

  useEffect(() => {
    document.documentElement.classList.add('lp-scroll-lock');
    return () => document.documentElement.classList.remove('lp-scroll-lock');
  }, []);

  useEffect(() => {
    if (!mobileNavOpen) return undefined;

    mobileNavRef.current?.querySelector('a')?.focus();
    const onKeyDown = (event) => {
      if (event.key !== 'Escape') return;
      setMobileNavOpen(false);
      mobileMenuButtonRef.current?.focus();
    };
    const onPointerDown = (event) => {
      if (
        mobileNavRef.current?.contains(event.target)
        || mobileMenuButtonRef.current?.contains(event.target)
      ) {
        return;
      }
      setMobileNavOpen(false);
    };

    window.addEventListener('keydown', onKeyDown);
    document.addEventListener('pointerdown', onPointerDown);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      document.removeEventListener('pointerdown', onPointerDown);
    };
  }, [mobileNavOpen]);

  useEffect(() => {
    const desktopQuery = window.matchMedia('(min-width: 761px)');
    const closeOnDesktop = (event) => {
      if (event.matches) setMobileNavOpen(false);
    };

    desktopQuery.addEventListener('change', closeOnDesktop);
    return () => desktopQuery.removeEventListener('change', closeOnDesktop);
  }, []);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return undefined;

    const reduced = prefersReducedMotion();
    const mobile = prefersFastMobileScroll();
    let lenis = null;
    let tickerFn = null;

    if (!reduced && !mobile) {
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
      if (reduced || mobile) {
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
            '.lp-locations-head',
            '.lp-location-card',
            '.lp-map-line',
            '.lp-gallery-head',
            '.lp-gallery-card',
            '.lp-story-line',
            '.lp-finale-inner',
          ],
          { clearProps: 'all', opacity: 1, y: 0, scale: 1, rotateX: 0, rotateY: 0, filter: 'none' },
        );

        if (!reduced) {
          gsap.from('.lp-feature-card, .lp-location-card, .lp-gallery-card, .lp-finale-inner', {
            scrollTrigger: {
              trigger: '.lp-command',
              start: 'top 82%',
              toggleActions: 'play none none none',
            },
            y: 18,
            opacity: 0,
            duration: 0.38,
            stagger: 0.05,
            ease: 'power2.out',
          });
        }
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

      const locationsTl = gsap.timeline({
        scrollTrigger: {
          trigger: '.lp-locations',
          start: 'top 78%',
          end: 'bottom 42%',
          scrub: 0.38,
        },
      });

      locationsTl
        .fromTo(
          '.lp-locations-head',
          { y: 46, opacity: 0, filter: 'blur(8px)' },
          { y: 0, opacity: 1, filter: 'blur(0px)', ease: 'none' },
          0,
        )
        .fromTo(
          '.lp-map-line',
          { scaleX: 0, opacity: 0 },
          { scaleX: 1, opacity: 1, ease: 'none' },
          0.08,
        )
        .fromTo(
          '.lp-location-card',
          { y: 88, opacity: 0, scale: 0.86, rotateX: 16 },
          {
            y: 0,
            opacity: 1,
            scale: 1,
            rotateX: 0,
            stagger: 0.12,
            transformOrigin: 'center bottom',
            ease: 'none',
          },
          0.14,
        );

      gsap.from('.lp-gallery-head, .lp-gallery-card', {
        scrollTrigger: {
          trigger: '.lp-gallery',
          start: 'top 82%',
          end: 'top 45%',
          scrub,
        },
        y: 56,
        opacity: 0,
        stagger: 0.08,
        ease: 'none',
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
    setMobileNavOpen(false);
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

      <header className={`lp-nav${mobileNavOpen ? ' lp-nav--open' : ''}`}>
        <div className="lp-brand">
          <span className="lp-mark" aria-hidden>
            虎
          </span>
          <span>BLIND TIGER</span>
        </div>
        <button
          ref={mobileMenuButtonRef}
          type="button"
          className="lp-menu-btn"
          aria-label={mobileNavOpen ? 'Close navigation menu' : 'Open navigation menu'}
          aria-expanded={mobileNavOpen}
          aria-controls="landing-navigation"
          onClick={() => setMobileNavOpen((open) => !open)}
        >
          <span />
          <span />
          <span />
        </button>
        <nav
          ref={mobileNavRef}
          className="lp-nav-links"
          id="landing-navigation"
          aria-label="Main navigation"
        >
          <a href="#flow" onClick={(e) => scrollToSection(e, 'flow')}>
            THE FLOW
          </a>
          <a href="#packages" onClick={(e) => scrollToSection(e, 'packages')}>
            PACKAGES
          </a>
          <a href="#gallery" onClick={(e) => scrollToSection(e, 'gallery')}>
            GALLERY
          </a>
          <a href="#membership" onClick={(e) => scrollToSection(e, 'membership')}>
            MEMBERSHIP
          </a>
          <Link to="/download" onClick={() => setMobileNavOpen(false)}>
            DOWNLOAD
          </Link>
        </nav>
      </header>
      <button
        type="button"
        className={`lp-nav-backdrop${mobileNavOpen ? ' is-open' : ''}`}
        aria-label="Close navigation menu"
        onClick={() => {
          setMobileNavOpen(false);
          mobileMenuButtonRef.current?.focus();
        }}
      />

      <section className="lp-hero-pin">
        <div className="lp-hero">
          <div className="lp-hero-copy">
            <p className="lp-eyebrow">CLUB DISTRICT · EXECUTIVE NIGHT</p>
            <h1 className="lp-title">
              BLIND TIGER
            </h1>
            <p className="lp-lede">
              TIME IS YOUR CURRENCY. Earn time. Spend time. Live more. Worry less.
            </p>
            <div className="lp-cta-row">
              <a className="lp-btn lp-btn-primary" href="#packages" onClick={(e) => scrollToSection(e, 'packages')}>
                BUY TIME
              </a>
              <Link className="lp-btn lp-btn-ghost" to="/download">
                DOWNLOAD FOR FREE
              </Link>
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
          <p className="lp-story-line lp-story-line-1">Your time starts now.</p>
          <p className="lp-story-line lp-story-line-2">Every second counts.</p>
          <p className="lp-story-line lp-story-line-3">
            Buy a package. Scan in. Spend minutes on the night —
            <br />
            not on every round at the bar.
          </p>
        </div>
      </section>

      <section className="lp-command" id="flow">
        <div className="lp-section-head">
          <p className="lp-eyebrow">THE FLOW</p>
          <h2>Buy. Scan. Spend.</h2>
          <p>
            Guests only notice the meter when it matters — like a phone battery,
            green to yellow to red.
          </p>
        </div>

        <div className="lp-features">
          <article className="lp-feature-card">
            <span className="lp-num">01</span>
            <div className="lp-ico">⏱</div>
            <h3>Buy time</h3>
            <p>
              Choose Quick Escape, Standard Night, After Hours, or Unlimited at the desk.
              Minutes and drinks credit to your phone.
            </p>
          </article>
          <article className="lp-feature-card lp-feature-card--hot">
            <span className="lp-num">02</span>
            <div className="lp-ico">⬚</div>
            <h3>Scan</h3>
            <p>
              Present your entry pass at the door. Your timer starts when you are inside —
              not while you wait in line.
            </p>
          </article>
          <article className="lp-feature-card">
            <span className="lp-num">03</span>
            <div className="lp-ico">虎</div>
            <h3>Spend</h3>
            <p>
              Standard drinks from your package. Premium moments — VIP lounge, secret room,
              photo booth — cost minutes.
            </p>
          </article>
        </div>
      </section>

      <section className="lp-command" id="packages">
        <div className="lp-section-head">
          <p className="lp-eyebrow">ENTRY PACKAGES</p>
          <h2>Invest your time wisely.</h2>
          <p>Four doors into the night. Drinks included. Time is the currency.</p>
        </div>
        <div className="lp-features">
          <article className="lp-feature-card">
            <span className="lp-num">₱699</span>
            <h3>Quick Escape</h3>
            <p>90 minutes · 2 drinks · After-work crowd</p>
          </article>
          <article className="lp-feature-card lp-feature-card--hot">
            <span className="lp-num">₱999</span>
            <h3>Standard Night</h3>
            <p>180 minutes · 4 drinks · Most guests</p>
          </article>
          <article className="lp-feature-card">
            <span className="lp-num">₱1,299</span>
            <h3>After Hours</h3>
            <p>240 minutes · 5 drinks · Late / weekend</p>
          </article>
          <article className="lp-feature-card">
            <span className="lp-num">₱1,799</span>
            <h3>Unlimited</h3>
            <p>Until closing · drinks incl. · VIP / members</p>
          </article>
        </div>
      </section>

      <section className="lp-locations">
        <div className="lp-locations-head">
          <p className="lp-eyebrow">NEXT DOORS</p>
          <h2>The tiger is moving through the city.</h2>
          <p>
            New cellar signals are coming online. Each room gets its own sound, crowd,
            and secret route into the night.
          </p>
        </div>

        <div className="lp-location-map" aria-label="Coming soon locations">
          <div className="lp-map-line" aria-hidden />
          <article className="lp-location-card lp-location-card--cubao">
            <span className="lp-location-kicker">COMING SOON</span>
            <h3>Cubao</h3>
            <p>
              Neon, vinyl, late-night crews. A louder room built for social play
              and one more round after the show.
            </p>
            <b>Quezon City signal</b>
          </article>

          <article className="lp-location-card lp-location-card--makati">
            <span className="lp-location-kicker">COMING SOON</span>
            <h3>Makati</h3>
            <p>
              After-work energy. Cash desk, polished booths, and a cellar mood
              for guests who stay past the first pour.
            </p>
            <b>Business district hideout</b>
          </article>
        </div>
      </section>

      <section className="lp-gallery" id="gallery">
        <div className="lp-gallery-head">
          <p className="lp-eyebrow">GALLERY</p>
          <h2>The night, captured.</h2>
          <p>
            Floor energy, booth light, and the red haze after midnight —
            moments Blind Tiger is built for.
          </p>
        </div>

        <div className="lp-gallery-grid" aria-label="Blind Tiger gallery">
          <article className="lp-gallery-card lp-gallery-card--large">
            <span>01</span>
            <div className="lp-gallery-frame">
              <img
                src="/gallery/frankie-cordoba-ghQjlrXlXeY-unsplash.jpg"
                alt="Guests dancing under warm club lights"
                loading="lazy"
              />
            </div>
            <h3>On the floor</h3>
            <p>Your time starts now — move with the room.</p>
          </article>

          <article className="lp-gallery-card lp-gallery-card--tall">
            <span>02</span>
            <div className="lp-gallery-frame">
              <img
                src="/gallery/aleksandr-popov-fa5QQ63u5W4-unsplash.jpg"
                alt="DJ booth overlooking a red-lit dance floor"
                loading="lazy"
              />
            </div>
            <h3>From the booth</h3>
            <p>Every second counts under the red beam.</p>
          </article>

          <article className="lp-gallery-card">
            <span>03</span>
            <div className="lp-gallery-frame">
              <img
                src="/gallery/jonas-jaeken-WY1AqSH4dUQ-unsplash.jpg"
                alt="Stage lights and confetti in a dark venue"
                loading="lazy"
              />
            </div>
            <h3>Peak hour</h3>
            <p>Extend your time when the night opens up.</p>
          </article>

          <article className="lp-gallery-card lp-gallery-card--wide">
            <span>04</span>
            <div className="lp-gallery-frame">
              <img
                src="/gallery/pim-myten-m41k1lTzjVM-unsplash.jpg"
                alt="Crowd silhouettes in deep red nightclub light"
                loading="lazy"
              />
            </div>
            <h3>After the scan</h3>
            <p>Invest your time wisely — inside the haze.</p>
          </article>
        </div>
      </section>

      <section className="lp-finale" id="membership">
        <div className="lp-finale-inner">
          <p className="lp-eyebrow">MEMBERSHIP</p>
          <h2>Extend your time.</h2>
          <p>
            Blind Tiger Club District — buy a package at the desk, scan in,
            and spend the night like time is the only currency that matters.
          </p>
          <div className="lp-cta-row" style={{ justifyContent: 'center' }}>
            <a className="lp-btn lp-btn-primary" href="#packages" onClick={(e) => scrollToSection(e, 'packages')}>
              YOUR TIME STARTS NOW
            </a>
            <Link className="lp-btn lp-btn-ghost" to="/download">
              DOWNLOAD FOR FREE
            </Link>
          </div>
        </div>
      </section>

      <footer className="lp-foot">
        <span>
          © Blind Tiger Club District ·{' '}
          <button className="lp-mvp-trigger" type="button" onClick={handleMvpClick}>
            MVP
          </button>
        </span>
        <span>Time is your currency</span>
      </footer>
    </div>
  );
}
