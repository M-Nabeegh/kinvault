import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

describe('README release contract', () => {
  it('documents local setup, architecture, privacy, synthetic data, tests, and v1 limits', () => {
    const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');

    expect(readme).toMatch(/quick start/i);
    expect(readme).toMatch(/architecture/i);
    expect(readme).toMatch(/privacy|security boundaries/i);
    expect(readme).toMatch(/synthetic data/i);
    expect(readme).toMatch(/npm test/i);
    expect(readme).toMatch(/limitations/i);
  });

  it('explains what each v1 feature does after it is used', () => {
    const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');

    for (const feature of ['dashboard', 'q&a', 'source preview', 'people', 'review', 'upload', 'privacy']) {
      expect(readme.toLowerCase()).toContain(feature);
    }
  });
});
