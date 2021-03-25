const cache = require('@actions/cache');

const main = async () => {
  console.log('restore cache');
  const tmp = process.env.TMPDIR || '/tmp';
  await cache.restoreCache([`${tmp}/drive/docker/cache`], 'alpine-node-drive-8ba6ad48229f3dff5348e03b04ecce8d00e67952', 'alpine-node-drive-');
}

main().catch(e => {
    console.error(e);
});
