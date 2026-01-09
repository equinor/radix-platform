package main

import (
	"context"
	"log"
	"strings"

	"github.com/equinor/radix-operator/pkg/apis/utils"
	"github.com/schollz/progressbar/v3"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	oldACR = "radixdev.azurecr.io"
	newACR = "radixdevdr.azurecr.io"
)

func main() {
	ctx := context.Background()
	_, radixclient, _, _, _, _, _ := utils.GetKubernetesClient(ctx)

	rds, err := radixclient.RadixV1().RadixDeployments("").List(ctx, metav1.ListOptions{})
	if err != nil {
		log.Fatalf("Unable to fetch deployments: %v", err)
	}

	bar := progressbar.Default(int64(len(rds.Items)), "syncing")

	for x, oldDeployment := range rds.Items {
		bar.Set(x + 1)
		newDeployment := oldDeployment.DeepCopy()
		ns := oldDeployment.GetNamespace()
		changes := false

		for i, c := range newDeployment.Spec.Components {
			if strings.HasPrefix(c.Image, oldACR) {
				newDeployment.Spec.Components[i].Image = strings.Replace(c.Image, oldACR, newACR, -1)
				changes = true
			}
		}

		for i, c := range newDeployment.Spec.Jobs {
			if strings.HasPrefix(c.Image, oldACR) {
				newDeployment.Spec.Jobs[i].Image = strings.Replace(c.Image, oldACR, newACR, -1)
				changes = true
			}
		}

		if changes {
			// Will perform update as patching not properly remove secret data entries
			_, err := radixclient.RadixV1().RadixDeployments(ns).Update(ctx, newDeployment, metav1.UpdateOptions{})
			if err != nil {
				log.Fatalf("failed to update deployment: %s.%s: %v", ns, newDeployment.Name, err)
			}

			bar.Describe(newDeployment.Name)
		}
	}
	bar.Finish()
}
