// Web Audio tactile mechanical sound synthesizer
class SoundEffects {
  private ctx: AudioContext | null = null;

  private initCtx() {
    if (!this.ctx && typeof window !== 'undefined') {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
  }

  // Crisp mechanical tactile switch sound
  playClick(type: 'num' | 'op' | 'eval' | 'clear' | 'toggle' = 'num') {
    try {
      this.initCtx();
      if (!this.ctx) return;

      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      const filter = this.ctx.createBiquadFilter();

      filter.type = 'lowpass';
      
      let freq = 800;
      let duration = 0.035;
      let volume = 0.08;

      if (type === 'op') {
        freq = 1100;
        volume = 0.1;
      } else if (type === 'eval') {
        freq = 1400;
        duration = 0.055;
        volume = 0.14;
      } else if (type === 'clear') {
        freq = 450;
        duration = 0.04;
        volume = 0.09;
      } else if (type === 'toggle') {
        freq = 950;
        duration = 0.03;
        volume = 0.07;
      }

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now);
      osc.frequency.exponentialRampToValueAtTime(120, now + duration);

      filter.frequency.setValueAtTime(3200, now);
      filter.frequency.exponentialRampToValueAtTime(300, now + duration);

      gain.gain.setValueAtTime(volume, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(now);
      osc.stop(now + duration);
    } catch {
      // Audio playback silently fails if autoplay restricted or unsupported
    }
  }

  private vibrationIntensity: 'light' | 'medium' | 'strong' | 'intense' = 'medium';

  setVibrationIntensity(intensity: 'light' | 'medium' | 'strong' | 'intense') {
    this.vibrationIntensity = intensity;
  }

  getVibrationIntensity(): 'light' | 'medium' | 'strong' | 'intense' {
    return this.vibrationIntensity;
  }

  triggerHaptic(customIntensity?: 'light' | 'medium' | 'strong' | 'intense') {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      try {
        const mode = customIntensity || this.vibrationIntensity;
        const durations: Record<string, number> = {
          light: 10,
          medium: 25,
          strong: 45,
          intense: 75,
        };
        const duration = durations[mode] ?? 25;
        navigator.vibrate(duration);
      } catch {
        // ignore
      }
    }
  }
}

export const soundFx = new SoundEffects();
