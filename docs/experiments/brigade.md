# Brigade

[Brigade](https://brigade.sh/) is a Kubernetes-native CI/CD tool that is written in Go and makes use of JavaScript for pipeline configuration.

## Pros
  * Kubernetes-native -> More integrated with Kubernetes
  * Light weight
  * JavaScript configuration/scripting

## Cons
  * Kubernetes-native -> Cannot be deployed outside Kubernetes (or a stand-alone system)
  * Still immature
  * Requires Github personal access tokens to pull down brigade.js. This can probably be fixed by creating a custom gateway where we pull brigade.js from a different source (which we probably would want anyway). Also, it's a ongoing issue with requests for proposals here: https://github.com/Azure/brigade/issues/407

The reason why Brigade needs a PAT (Personal Access Token) is that it uses it to authenticate to the Github REST Api in order to retrieve set status on commits as well as retrieving the brigade.js file to start the pipeline.

We can work around this by creating our own Github gateway where we skip the full Github integration and pull the brigade.js file from somewhere we control and thus avoid having to have it as part of each project.

Another solution could be to add the deploy key to the Brigade project configuration as well as the brigade.js content under defaultScript - this will then bypass the need for retrieving it from the repo.
This will add administrative overhead when number of projects grow and you have to update all the pipeline scripts in all the project configurations.