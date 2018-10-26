# Docker image registries

We need a Docker compatible registry to push built Docker images after they have been built before they are deployed.

  * We MAY want to use security scanning provided by the Docker registry. 
    * PRO: It is easier to get started compared to building it elsewhere in the build pipeline.
    * CON: It creates a lock in and much larger threshold to changing Docker registry vendor later the deeper we integrate with one vendor.

  * We MAY need advanced permission controls. Right now there is no known need.
    * Q: Are (and if, when) developers going to push directly to Docker registry using their own Azure AD permissions?

  * We MAY want to store other artifacts such as binaries, jars, npm packages as well. But right now Docker image is our base composable component. If we want all-in-one it basically limits us to 1 product on the market.

## Alternatives

| Offering                    | Type           | Pros                                                             | Cons                                                                            | Notes  |
| ---                    | ---           | ---                                                             | ---                                                                            | ---  |
| Azure ACR                   | Cloud          | Integrated with AD                                               | No security scanning. Only Docker images.                                       |        |
| Amazon ECR                  | Cloud          |                                                                  | Only Docker images.                                                             |        |
| Docker hub/Docker Cloud     | Cloud          |                                                                  | No security scanning. Only Docker images.                                       |        |
| Docker Trusted Repository   | On-prem        | Security scanning integrated.                                    | Only Docker images.                                                             |        |
| Harbor                      | On-prem        |                                                                  | Only Docker images.                                                             |        |
| Nexus Repository Manager 3  | On-prem        | All types of repos. Docker, Helm, NPM, Maven. LDAP/SSO support.  | Seems like the Jenkins of artifactories.                                        |        |
| Quay Enterprise             | On-prem        | LDAP/SSO Support                                                 | Only Docker images.                                                             |        |
| Quay.io                     | Cloud          | Security scanning integrated.                                    | No LDAP/SSO. Only Docker images and Helm charts.                                |        |
| jFrog                       | Cloud+On-prem  | All types of repos. Docker, Helm, NPM, Maven. LDAP/SSO support.  |                                                                                 |        |
| GitLab CR                   | Cloud+On-prem  |                                                                  | Coupled with GitLab. Probably not possible to run only CR. Only Docker images.  |        |
|                             |                |                                                                  |                                                                                 |        |

## Selection

As we don't yet know our future needs with regards to other-than-Docker-type repositories and third party authentication integrations we for now opt for the simpler Quay.io. We will test it with our current Brigade pipeline.

After discussing with the whole Radix team, we decided to use Azure ACR for the time being.

## Results

Pushing a Docker image to a private repository on `quay.io` through a Brigade pipeline is fairly straight-forward like pushing to other Docker registry.
