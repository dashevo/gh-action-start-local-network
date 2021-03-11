const semver = require('semver');

/**
 * Get MAJOR.MINOR release version by version from package
 *
 * @param {string} packageVersion
 * @param {Object} [options]
 * @param {string} [options.overrideMajorVersion]
 *
 * @return {string}
 */
function getReleaseVersion(packageVersion, options = {}) {
  const prerelease = semver.prerelease(packageVersion);
  const major = semver.major(packageVersion);
  const minor = semver.minor(packageVersion);

  const majorVersion = options.overrideMajorVersion !== undefined
    ? options.overrideMajorVersion
    : major;

  let version = `${majorVersion}.${minor}`;

  if (prerelease) {
    version = `${version}-${prerelease[0]}`;
  }

  return version;
}

module.exports = getReleaseVersion;
