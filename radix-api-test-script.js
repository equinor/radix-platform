// Running:
// AZ_TOKEN=$(az account get-access-token | jq -r .accessToken) k6 run --vus 20 --duration 1800s --insecure-skip-tls-verify radix-api-test-script.js 

import { check, sleep } from "k6";
import http from "k6/http";

const cluster = 'playground-master-47.dev.radix.equinor.com'
const service = 'server-radix-api-qa'
const path = '/api/v1/applications/radix-web-console'

export default function() {

    const token = `${__ENV.AZ_TOKEN}`

    var url = "https://" + service + "." + cluster + path;

    url = "https://playground-playground-maste-16ede4-f4e9b2c6.hcp.northeurope.azmk8s.io/apis/batch/v1/jobs"

    let params = {
        headers: { 
            "Content-Type": "application/json",
            "Authorization": "Bearer " + token
        }
    };

    var r = http.get(url, params);

    check(r, {
        "status is 200": (r) => r.status === 200
    });

    //console.log(JSON.stringify(r))
}











