import { useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useAuth } from '../context/AuthContext';
import './landing.css';

gsap.registerPlugin(ScrollTrigger);

export default function LandingPage() {
  const rootRef = useRef(null);
  const { profile } = useAuth();

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Hero: pin + scrub like AirPods product stage
      const heroTl = gsap.timeline({
        scrollTrigger: {
          trigger: '.lp-hero-pin',
          start: 'top top',
          end: '+=160%',
          scrub: 1.1,
          pin: true,
          anticipatePin: 1,
        },
      });

      heroTl
        .fromTo('.lp-hero-copy', { y: 40, opacity: 0.55 }, { y: 0, opacity: 1, ease: 'none' }, 0)
        .fromTo(
          '.lp-emblem',
          { scale: 0.72, rotateY: -28, rotateX: 12, opacity: 0.5 },
          { scale: 1.08, rotateY: 8, rotateX: -4, opacity: 1, ease: 'none' },
          0,
        )
        .fromTo('.lp-claw', { scaleY: 0.4, opacity: 0 }, { scaleY: 1, opacity: 1, ease: 'none' }, 0.05)
        .fromTo(
          '.lp-float-card',
          { y: 80, opacity: 0, rotateZ: -6 },
          { y: 0, opacity: 1, rotateZ: 0, ease: 'none' },
          0.15,
        )
        .fromTo(
          '.lp-dash-preview',
          { y: 120, opacity: 0, scale: 0.86, rotateY: 18 },
          { y: 0, opacity: 1, scale: 1, rotateY: 0, ease: 'none' },
          0.25,
        )
        .fromTo('.lp-orb', { opacity: 0.2, scale: 0.6 }, { opacity: 0.9, scale: 1.15, ease: 'none' }, 0)
        .to('.lp-hero-stats', { opacity: 1, y: 0, ease: 'none' }, 0.35);

      gsap.from('.lp-hero-stats .lp-stat', {
        scrollTrigger: {
          trigger: '.lp-hero-pin',
          start: 'top top',
          end: '+=80%',
          scrub: true,
        },
        y: 28,
        opacity: 0,
        stagger: 0.12,
      });

      // Command room section — cards fan in on scroll
      gsap.from('.lp-section-head', {
        scrollTrigger: {
          trigger: '.lp-command',
          start: 'top 75%',
          end: 'top 40%',
          scrub: true,
        },
        y: 60,
        opacity: 0,
      });

      gsap.from('.lp-feature-card', {
        scrollTrigger: {
          trigger: '.lp-features',
          start: 'top 80%',
          end: 'top 35%',
          scrub: 1,
        },
        y: 100,
        opacity: 0,
        rotateX: 18,
        stagger: 0.15,
        transformOrigin: 'center bottom',
      });

      // Mid sticky narrative — text crossfade like AirPods copy blocks
      const storyTl = gsap.timeline({
        scrollTrigger: {
          trigger: '.lp-story-pin',
          start: 'top top',
          end: '+=120%',
          scrub: 1,
          pin: true,
        },
      });

      storyTl
        .fromTo('.lp-story-line-1', { opacity: 0.15, y: 30 }, { opacity: 1, y: 0 })
        .to('.lp-story-line-1', { opacity: 0.2, y: -20 }, '+=0.2')
        .fromTo('.lp-story-line-2', { opacity: 0, y: 40 }, { opacity: 1, y: 0 }, '<0.1')
        .to('.lp-story-line-2', { opacity: 0.25, y: -16 }, '+=0.25')
        .fromTo('.lp-story-line-3', { opacity: 0, y: 40 }, { opacity: 1, y: 0 }, '<0.1');

      // Final CTA stage
      gsap.from('.lp-finale-inner', {
        scrollTrigger: {
          trigger: '.lp-finale',
          start: 'top 70%',
          end: 'top 30%',
          scrub: true,
        },
        scale: 0.92,
        opacity: 0,
        filter: 'blur(8px)',
      });

      // Soft parallax on glow
      gsap.to('.lp-glow-a', {
        scrollTrigger: { trigger: rootRef.current, scrub: true, start: 'top top', end: 'bottom bottom' },
        y: -180,
        ease: 'none',
      });
      gsap.to('.lp-glow-b', {
        scrollTrigger: { trigger: rootRef.current, scrub: true, start: 'top top', end: 'bottom bottom' },
        y: 220,
        ease: 'none',
      });
    }, rootRef);

    return () => ctx.revert();
  }, []);

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
          <a href="#suite">SUITE</a>
          <Link to="/login">ACCESS</Link>
        </nav>
      </header>

      {/* HERO — pinned scroll stage */}
      <section className="lp-hero-pin">
        <div className="lp-hero">
          <div className="lp-hero-copy">
            <p className="lp-eyebrow">私 人 会 所 · OPERATIONS SUITE</p>
            <h1 className="lp-title">
              The tiger behind
              <br />
              the velvet door.
            </h1>
            <p className="lp-lede">
              Blind Tiger Admin is the private command room for the night — built for investor demos
              and bar pilots. Cash-first time economy. Guarded access. Live pulse.
            </p>
            <div className="lp-cta-row">
              <Link className="lp-btn lp-btn-primary" to={profile ? '/app' : '/login'}>
                {profile ? 'ENTER THE SUITE' : 'REQUEST PRIVATE DEMO'}
              </Link>
              <a className="lp-btn lp-btn-ghost" href="#suite">
                WATCH THE COMMAND ROOM
              </a>
            </div>
            <div className="lp-hero-stats">
              <div className="lp-stat">
                <strong>₱101K</strong>
                <span>CASH PULSE</span>
              </div>
              <div className="lp-stat">
                <strong>6060m</strong>
                <span>TIME LOADED</span>
              </div>
              <div className="lp-stat">
                <strong>01</strong>
                <span>ACTIVE VISITS</span>
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
              LIVE COMMAND · ₱101,000
              <small>Cash-first time economy on the floor</small>
            </div>
            <div className="lp-dash-preview">
              <div className="lp-dash-side">
                <b>BLIND TIGER</b>
                <span>Dashboard</span>
                <span>Load Time</span>
                <span>Members</span>
                <span>Events</span>
                <span>Guests</span>
                <span>HR</span>
              </div>
              <div className="lp-dash-main">
                <h3>Operations Dashboard</h3>
                <div className="lp-dash-grid">
                  <div>
                    <em>12</em>
                    <small>Members</small>
                  </div>
                  <div>
                    <em>01</em>
                    <small>Active</small>
                  </div>
                  <div>
                    <em>₱101K</em>
                    <small>Cash today</small>
                  </div>
                  <div>
                    <em>6060m</em>
                    <small>Time loaded</small>
                  </div>
                </div>
                <p>Upcoming events · investor night · guest list locked</p>
              </div>
            </div>
          </div>
        </div>
        <p className="lp-scroll-hint">Scroll to enter the suite</p>
      </section>

      {/* STORY — AirPods-style copy scrub */}
      <section className="lp-story-pin">
        <div className="lp-story">
          <p className="lp-story-line lp-story-line-1">It’s operations,</p>
          <p className="lp-story-line lp-story-line-2">remastered for the night.</p>
          <p className="lp-story-line lp-story-line-3">
            Time as currency. Cash at the desk.
            <br />
            The house sees everything — guests feel the club in their pocket.
          </p>
        </div>
      </section>

      {/* COMMAND ROOM FEATURES */}
      <section className="lp-command" id="suite">
        <div className="lp-section-head">
          <p className="lp-eyebrow">COMMAND ROOM / 夜间运营</p>
          <h2>A luxury backend for the business after dark.</h2>
          <p>
            This landing frames the dashboard as a private operating system: rich, guarded, and
            investor-ready — before you unlock the live suite.
          </p>
        </div>

        <div className="lp-features">
          <article className="lp-feature-card">
            <span className="lp-num">01</span>
            <div className="lp-ico">⚙︎₱</div>
            <h3>Cash pulse as theater</h3>
            <p>
              Real-time money movement and polished status — so a pilot night looks as sharp as it
              runs.
            </p>
          </article>
          <article className="lp-feature-card lp-feature-card--hot">
            <span className="lp-num">02</span>
            <div className="lp-ico">⚙︎✓</div>
            <h3>Members behind the curtain</h3>
            <p>
              Access control and guest lists framed as a gated house system — ban, whitelist, VIP
              nights.
            </p>
          </article>
          <article className="lp-feature-card">
            <span className="lp-num">03</span>
            <div className="lp-ico">⚙︎▣</div>
            <h3>Events with a pulse</h3>
            <p>
              Calendar and operational states become investor-friendly scenes — the floor has a
              story.
            </p>
          </article>
        </div>
      </section>

      {/* FINALE */}
      <section className="lp-finale">
        <div className="lp-finale-inner">
          <p className="lp-eyebrow">PRIVATE ACCESS</p>
          <h2>Enter the command room.</h2>
          <p>Admin & HR only. Cash desk, time loads, guest list, HR — ready for your walkthrough.</p>
          <Link className="lp-btn lp-btn-primary" to={profile ? '/app' : '/login'}>
            {profile ? 'OPEN OPERATIONS DASHBOARD' : 'SIGN IN TO THE SUITE'}
          </Link>
        </div>
      </section>

      <footer className="lp-foot">
        <span>© Blind Tiger Operations Suite · MVP</span>
        <Link to="/login">Access</Link>
      </footer>
    </div>
  );
}
