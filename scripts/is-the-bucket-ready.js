const bucketName = process.argv[2];
const username = process.argv[3];
const password = process.argv[4];
const couchbaseVersion = process.argv[5];

const couchbaseVersionSplit = 5;

var couchbase = require('couchbase');
var couchbaseOptions = {};

// If the couchbase version is 5 or greater then authenticate.
// For older versions this is unnecessary and will cause an error
if (parseInt(couchbaseVersion.charAt(0), 10) >= couchbaseVersionSplit) {
  couchbaseOptions = {
    username,
    password
  };
}

var cluster = new couchbase.Cluster(
  "http://127.0.0.1:8091",
  couchbaseOptions
);

try {
  var bucket = cluster.bucket(bucketName);
  bucket.ping().then((pingResult) => {
    console.log(`Successfully pinged bucket: ${bucketName}`);
    console.log(`Version: ${pingResult.version}`)
    process.exit(0);
  }).catch((error) => {
    console.error(`Ping to bucket ${bucketName} failed with the following error:`);
    console.error(error);
    process.exit(1);
  })
} catch (e) {
  console.log(e);
  process.exit(1);
}
