node('git && linux && docker') {
    def app
    
    stage('Preparation') {
        checkout scm
    }
    
    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-btburnett3') {
        stage('Build image') {            
            app = docker.build("btburnett3/couchbasefakeit", "--no-cache --pull --build-arg COUCHBASE_TAG=${params.COUCHBASE_TAG} .")
        }
        
        stage('Push image') {
            app.push(params.COUCHBASE_TAG)
            
            if (params.COUCHBASE_TAG.equals("enterprise-6.5.1")) {
                app.push("latest")
            }
        }
    }
}
