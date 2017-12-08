const bucketName = process.argv[2];
const username = process.argv[3];
const password = process.argv[4];

var couchbase = require('couchbase')
var cluster = new couchbase.Cluster("http://127.0.0.1:8091");
cluster.authenticate(username, password);


var bucket = cluster.openBucket(bucketName, err => {
	if (err) {
		console.error(`Failed to open bucket connection to ${bucketName}`);
		process.exit(1);
	}
});

var key = "ping"
bucket.upsert(key, "ping", err => {
	if (err) {
		// TODO clupo what if this isn't the usual error. like what if it's an auth error
		console.log(err);
		process.exit(1);
	}
		
	// Don't keep the ping document in the bucket
	bucket.remove(key, err => {
		if (err) {
			console.log(`${key} document was not removed`);
			process.exit(1);
		}
		
		process.exit(0);
	});
});