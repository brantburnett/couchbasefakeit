node('git && docker') {
    def app
    
    stage('Preparation') {
        checkout scm
    }
    
    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-btburnett3') {
        stage('Build image') {
            // replace FROM line
            sh("sed -i \"1s/.*/FROM couchbase\\/server:${params.COUCHBASE_TAG}/\" Dockerfile")
            
            app = docker.build("btburnett3/couchbasefakeit", "--no-cache --pull .")
        }
        
        stage('Push image') {
            app.push(params.COUCHBASE_TAG)
			
			if (params.COUCHBASE_TAG.equals("enterprise-4.6.3")) {
				app.push("latest")
			}
        }
    }
}