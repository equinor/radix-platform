====== Jenkins pipeline scripts ======

===== Release 1. =====

===== CI =====

The CI pipeline in STaaS is configured as a job per app in Jenkins.\\ 
Jenkins is hosted inside Kubernetes using the [[https://github.com/kubernetes/charts/tree/master/stable/jenkins|Jenkins helm chart]], where it will provide a master and slave cluster utilizing the Jenkins Kubernetes plugin.

==== Adding an existing app to STaaS ====

//Precondition//\\ 
- The app must be "dockerized", that is it has to be able to be built and run in a container by Docker using a single Dockerfile
- The app repo must be hosted in Github

//Step 1//\\
Developer contacts STaaS team and provide them with
  * a link to github repo
  * the branch to be used for building the app

//Step 2//\\
The STaaS team will create a job in Jenkins for the app and
  * add repo to pull from
  * set Jenkins to poll the repo and watch for changes in given branch

//Step 3//\\
The STaaS them will provide the developer with 2 files
  * a public key that has to be added to the github repo so Jenkins can read it
  * a jenkinsfile which should be added to the project

//Step 4//\\ 
The developer then configure the jenkinsfile by adding/changing the app image name and version to be built.

//Step 5//\\ 
To start a new build then the developer simply push to the Github repo.

==== Adding a new app to STaaS ====

todo\\ 
https://github.com/Statoil/staas-template-generator

==== Adding a new Jenkins job to Jenkins ====

In the first release it is done manually via Jenkins console (GUI).

Login to Jenkins and add a new pipeline job:
  * Click ''New item''
  * Fill in the name of the job in the ''Enter an item name'' field
  * Choose ''Pipeline'' project
  * In ''Build Triggers'' section, check ''Poll SCM''
  * In the ''Schedule'' field insert ''* * * * *'' (in the first release we poll the repository every minute)
  * In the ''Pipeline'' section, choose ''Pipeline script from SCM'' in the ''Definition'' dropdown
  * Enter the ''Repository URL'' field to point to the application's source code repository (i.e. GitHub)
  * Generate a public/private key pairs (e.g. using ''ssh-keygen''), and add the private key to Jenkins ''Credentials''
  * Choose the added ''Credentials'' in the ''Credentials'' dropdown menu
  * Enter the branch to be built in the ''Branch Specifier'' field
  * Go to GitHub repository: ''Settings'' > ''Deployed keys'' > ''Add deploy key'' > Paste the generated public key

===== CD =====
This is a manual process, a STaaS admin has to deploy each app using kubectl.

===== Release 2. =====

===== CI =====

==== Modifying an existing Jenkins job for GitHub Webhook trigger ====

The following steps require [[https://wiki.jenkins.io/display/JENKINS/Github+Plugin|GitHub plugin]] to be installed in Jenkins.

Note that a deploy key on GitHub is still needed for Jenkins to communicate with GitHub, similar to **Release 1**.

In Jenkins:
  * Click an existing job, then click ''Configure''
  * In ''Build Triggers'' section, check ''GitHub hook trigger for GITScm polling''
  * Get Hook URL: ''Jenkins'' > ''Manage Jenkins'' > ''Configure System'' > ''GitHub'' > Click ''?'' > Copy the URL

In GitHub:
  * ''Settings'' > ''Webhooks'' > ''Add webhook'' > Paste Hook URL in the ''Payload URL'' field

Security measures:
  * 2 network security group policies are added in Azure to limit inbound traffic to Jenkins on port 8080 only to GitHub hooks (https://api.github.com/meta) and office (might need to be updated).

===== CD =====

A simple NodeJS application (https://github.com/Statoil/staas-cd-app) has been created and deployed in our Kubernetes cluster for automating the deployment of a container image. This deployment app is currently being called via HTTP GET request with several query parameters, which makes it simple to be called from a Jenkins Slave pod. It currently still uses the default service account, which should be changed if we decide to move forward with our own solution later on.