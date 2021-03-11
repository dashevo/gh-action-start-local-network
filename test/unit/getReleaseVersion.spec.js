const getReleaseVersion = require('../../src/getReleaseVersion');

describe('getReleaseVersion', () => {
  it('should return MINOR.MAJOR version from package version', () => {
    const result = getReleaseVersion('0.14.2');

    expect(result).to.equal('0.14');
  });

  it('should return MINOR.MAJOR-dev version from package version if pre-release', () => {
    const result = getReleaseVersion('0.14.2-dev.1');

    expect(result).to.equal('0.14-dev');
  });

  it('should return MINOR.MAJOR version overriding MAJOR if specified', () => {
    const result = getReleaseVersion('0.14.2', {
      overrideMajorVersion: 42,
    });

    expect(result).to.equal('42.14');
  });

  it('should return MINOR.MAJOR-dev version overriding MAJOR if specified', () => {
    const result = getReleaseVersion('0.14.2-dev.1', {
      overrideMajorVersion: 42,
    });

    expect(result).to.equal('42.14-dev');
  });
});
