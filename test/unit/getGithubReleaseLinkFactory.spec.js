const getGithubReleaseLinkFactory = require('../../src/getGithubReleaseLinkFactory');

describe('getGithubReleaseLinkFactory', () => {
  let getGithubReleaseLink;
  let githubMock;
  let repoMock;
  let releases;

  beforeEach(function beforeEach() {
    releases = [
      { tag_name: 'v0.14.0', tarball_url: 'url/1' },
      { tag_name: 'v0.14.42', tarball_url: 'url/42' },
    ];

    githubMock = {
      getRepo: this.sinonSandbox.stub(),
    };

    repoMock = {
      listReleases: this.sinonSandbox.stub(),
    };

    githubMock.getRepo.returns(repoMock);

    repoMock.listReleases.resolves({
      data: releases,
    });

    getGithubReleaseLink = getGithubReleaseLinkFactory(githubMock);
  });

  it('should return latest tag link based on package version and repository url', async () => {
    const result = await getGithubReleaseLink('0.14.0-dev.1', 'dashevo/test');

    expect(result).to.equal('url/42');
    expect(githubMock.getRepo).to.have.been.calledWithExactly('dashevo', 'test');
  });

  it('should return latest tag link based on package version and repository url with overrided MAJOR', async () => {
    const result = await getGithubReleaseLink('1.14.0-dev.1', 'dashevo/test', {
      overrideMajorVersion: 0,
    });

    expect(result).to.equal('url/42');
    expect(githubMock.getRepo).to.have.been.calledWithExactly('dashevo', 'test');
  });

  it('should throw an error if no matching versions found among releases', async () => {
    releases = [
      { tag_name: 'v0.1.0', tarball_url: 'url/1' },
      { tag_name: 'v0.1.42', tarball_url: 'url/42' },
    ];

    repoMock.listReleases.resolves({ data: releases });

    try {
      await getGithubReleaseLink('0.14.0-dev.1', 'dashevo/test');
      expect.fail('error was not thrown');
    } catch (e) {
      expect(e.message).to.equal('No matching releases found for version 0.14.0-dev.1 in dashevo/test');
    }
  });
});
