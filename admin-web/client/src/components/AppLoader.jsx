export default function AppLoader({ label = 'Loading Blind Tiger…' }) {
  return (
    <div className="app-loader" role="status" aria-live="polite">
      <div className="app-loader-inner">
        <div className="app-loader-mark" aria-hidden>
          <span className="app-loader-ring" />
          <span className="app-loader-core" />
        </div>
        <p className="app-loader-brand">THE BLIND TIGER</p>
        <p className="app-loader-label">{label}</p>
      </div>
    </div>
  );
}
