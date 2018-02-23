## Overview

couchbasefakeit is a Docker image designed for testing and local development.  It starts up a single, standalone [Couchbase Server](http://couchbase.com) instance within a Docker container and initializes it with buckets, indexes, and fake data that you define.  Fake data is generated using [FakeIt](https://www.npmjs.com/package/fakeit).

This can be very useful in reducing developer friction, providing a way to quickly and easily spin up a Couchbase server preinitialized for your application.  By including an Dockerfile and associated configuration files within your source control repo, you can version your development data definitions along with your application.

## Pulling

The latest version can be pulled using:

```sh
docker pull btburnett3/couchbasefakeit:latest
```

The `latest` tag will be the latest Enterprise edition of Couchbase, with the latest release of FakeIt.

Specific versions may also be available, such as `enterprise-4.6.3`.  This would be the Enterprise edition of Couchbase, version 4.6.3.

## Using couchbasefakeit

To use couchbasefakeit, create your own Dockerfile that uses couchbasefakeit as its base image.  Then add configuration files to the /startup directory of the new image.  You may also override environment variables to change the Couchbase Server configuration.

```dockerfile
FROM btburnett3/couchbasefakeit:latest

# Customize environment
ENV CB_DATARAM=256 \
    CB_PASSWORD=mypassword

# Copy files
COPY . /startup/
```

### Environment Variables

The following environment variables can be set to change the Couchbase Server configuration:

| Env Variable    | Description                                                    |
| ------------    | -----------                                                    |
| CB_DATARAM      | Data service RAM in megabytes, default `512`                   |
| CB_INDEXRAM     | Index service RAM in megabytes, default `256`                  |
| CB_SEARCHRAM    | Search (FTS) service RAM in megabytes, default `256`           |
| CB_SERVICES     | Services to enable, default `kv,n1ql,index,fts`                |
| CB_INDEXSTORAGE | Index storage mode, `forestdb` (default) or `memory_optimized` |
| CB_USERNAME     | Couchbase user name, default `Administrator`                   |
| CB_PASSWORD     | Couchbase password, default `password`                         |

Values for CB_SERVICES and CB_INDEXSTORAGE correspond to parameters for the [Couchbase REST API](https://developer.couchbase.com/documentation/server/4.6/rest-api/rest-endpoints-all.html).

### Bucket Configuration

To configure your buckets, simply place a `buckets.json` file in the `/startup` directory of your image.  This file should contain an array of bucket definition objects.

```json
[
  {
    "name": "sample",
    "ramQuotaMB": 100,
    "bucketType": "membase",
    "authType": "sasl",
    "saslPassword": "",
    "evictionPolicy": "fullEviction",
    "replicaNumber": 0,
    "flushEnabled": 1
  },
  {
    "name": "default",
    "ramQuotaMB": 100,
    "bucketType": "membase",
    "authType": "sasl",
    "saslPassword": "",
    "evictionPolicy": "fullEviction",
    "replicaNumber": 0,
    "flushEnabled": 1
  }
]
```

Attribute names and values in this file correspond with the [Couchbase REST API create bucket endpoint](https://developer.couchbase.com/documentation/server/4.6/rest-api/rest-bucket-create.html).

If this file is not overridden in your image, it will create a single bucket named `default` with a RAM quota of 100MB.

### Generating Data With FakeIt

To generate data with FakeIt, create a directory underneath `/startup` with the name of your bucket, and directory beneath that named `models`.  For example, `/startup/sample/models`.  Note that the names are case sensitive.  Add your FakeIt YAML models to the models directory.

FakeIt will be run using these models automatically during startup.  
You may also include inputs, such as CSV files, in the image to be referenced by the models.

This process will be run before indexes are created so that index updates don't degrade the performance of the data inserts.

### Creating Views

To create views, add a directory underneath `/startup` with the name of your bucket and a text file named `views.json`.  This file should be a JSON object with one or more design document specifications.  The name of each attribute should be the name of the design document.

```json
{
  "customers": {
    "views": {
        "CustomersByFirstName": {
            "map": "function (doc, meta) {\n  if ((doc.type === \"customer\") && doc.firstName) {\n    emit(doc.firstName, null);\n  }\n}"
        }
    }
  }
}
```

Examples of the syntax for design documents can be found [in the Couchbase documentation](https://developer.couchbase.com/documentation/server/current/rest-api/rest-ddocs-create.html).  Note that `views.json` has an extra nesting level above the Couchbase examples, as it supports more than one design document in a single file.

### Creating Indexes

To create indexes, add a directory underneath `/startup` with the name of your bucket and a text file named `indexes.n1ql`.  For example, `/startup/default/indexes.n1ql`.  Note that the names are case sensitive.

Within this file, you can define the `CREATE INDEX` statements for your bucket, separated by semicolons.  It is recommended for performance to use `WITH {"defer_build": true}` for all indexes, and use a `BUILD INDEX` statement at the end of the file.

```sql
CREATE PRIMARY INDEX `#primary` ON default WITH {"defer_build": true};
CREATE INDEX `Types` ON default (`type`) WITH {"defer_build": true};
BUILD INDEX ON default (`#primary`, `Types`)
```

### Creating Indexes with YAML

Alternatively, you may add YAML files with index definitions under the `/startup/<bucketname>/indexes` folder.  This operation uses [couchbase-index-manager](https://www.npmjs.com/package/couchbase-index-manager) to create the indexes.  [See here](https://www.npmjs.com/package/couchbase-index-manager#definition-files) for an explanation of the YAML file format.

### Creating Full Text Search Indexes

To create FTS indexes, add a directory underneath `/startup` with the name of your bucket, and underneath that a `fts` directory.  Within that, add a json file for each index, with the file name being the index name.  For example, `/startup/default/fts/my_index.json`.  Note that names are case sensitive.

Within this file, place the JSON index definition.  This can be easily exported from the Couchbase Console.

To create FTS index aliases, add an additional file in the same folder named `aliases.json`.  This file should be an object with each attribute being an alias name, and the value being an array of index names.

```json
{
    "my_alias": ["my_index"],
    "my_second_alias": ["my_index_2", "my_index_3"]
}
```

### Example

An example image configuration can be found [here](example/).

To run the example locally:

1. Ensure that Couchbase Server is not currently running on your machine to avoid port conflicts
2. `git clone https://github.com/brantburnett/couchbasefakeit.git`
3. `cd couchbasefakeit/example`
4. `docker-compose up -d`
5. The server will be accessible at http://localhost:8091 after 15-30 seconds. The username is "Administrator", password is "mypassword".

To shut down and cleanup:

1. `docker-compose down`

For more detailed examples of FakeIt models, see https://github.com/bentonam/fakeit/tree/dev/test/fixtures/models.