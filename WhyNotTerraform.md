# Why Not Terraform?

This discussion applies equally to OpenTofu and to any declarative
infrastructure-as-code tool with a state-driven apply model. It also applies
to all cloud vendors, not just AWS. On clouds other than AWS, where there may
not be a mature CLI like eksctl, Terraform may well be the best option
available — in which case the approach described in
[Making Terraform Work Like This](#making-terraform-work-like-this) is worth
considering.


## The Problem

A Kubernetes cluster upgrade is not a single atomic operation. It is an
ordered sequence of steps with human judgement required between them:

1. Upgrade addons to their latest versions for the current control plane
2. Upgrade the control plane itself
3. Upgrade addons again to match the new control plane version
4. Create new nodegroups running the new version
5. Lock old nodegroup sizes so the autoscaler leaves them alone
6. Cordon old nodegroups so no new work lands on them
7. Verify something low-risk migrates cleanly
8. Carefully migrate singletons and stateful workloads
9. Drain old nodegroups to move everything remaining
10. Confirm the cluster is healthy
11. Delete old nodegroups

Steps 7, 8, and 10 are where an experienced operator looks at the cluster,
checks dashboards, talks to application owners, and decides whether to
proceed, pause, or roll back. Terraform has no model for this. Its job is to
converge current state to desired state in one pass.


## The Default Terraform Approach Is The Fast Path

When you change a nodegroup version in your HCL and run `terraform apply`,
Terraform destroys the old nodegroup and creates a new one. There is no
intermediate state where both exist. This is functionally equivalent to
running `cluster upgrade fast-end-to-end-automatic` — it works, but only if
every workload in the cluster has:

- Multiple replicas behind a service
- Pod Disruption Budgets
- All three health probes (startup, liveness, readiness)
- Appropriate code/behaviour backing all three probes
- An appropriate termination grace period
- Graceful shutdown handling that uses that grace period to refuse traffic and finish work

Clusters with 100% perfectly configured workloads are rarer than hen's teeth.
If you have singletons, workloads without PDBs, or anything that needs manual
intervention during migration, the atomic replace approach will cause outages.


## EKS Auto Mode and Managed Node Group Force Updates

AWS offers EKS Auto Mode and managed node group update strategies that handle
the upgrade for you. These are the cloud vendor's version of the same thing:
replace nodes, trust that your workloads can handle it. The same caveats
apply. If your workloads are not resilient, you will experience disruption.
The vendor is not checking your dashboards between steps.


## Making Terraform Work Like This

It is possible to build a Terraform-based workflow that approximates the
careful multiple automatic step approach. The pattern looks like this:

1. Package Terraform in a container image alongside scripts
2. Scripts modify the HCL on the fly to create intermediate states:
   - First apply: add new nodegroups alongside old ones
   - Run kubectl commands to cordon and drain old nodegroups
   - Second apply: remove old nodegroup definitions
3. Use `terraform apply -target` or workspace manipulation to control what
   changes when

This works, but you are now fighting the tool. Terraform's value proposition
is that you declare desired state and it converges. The moment you start
generating intermediate HCL, sequencing multiple applies, and shelling out to
kubectl between them, you have an imperative workflow wearing a declarative
costume. You have all the complexity of the imperative approach plus the
overhead of state file management, plan/apply cycles, and HCL generation.

If this is your only option (perhaps your cloud vendor has no eksctl
equivalent), it is a reasonable approach. But if you have a choice, purpose
built imperative tooling is simpler and more honest about what is actually
happening. But on AWS this system is the best way to do EKS maintenance.


## Where Terraform Wins

Terraform is excellent for Day 1 provisioning:

- VPCs, subnets, and network topology
- IAM roles, policies, and service accounts
- DNS zones, certificates, load balancers (though there are better ways, see below)
- Any infrastructure that is genuinely declarative: you define it, it exists

For resources that are created once and rarely changed, the declarative model
is a natural fit. Terraform's strength is ensuring that your infrastructure
matches your definition and detecting drift.


## The Sweet Spot

Use the best tool for each purpose. Terraform provisions the underlying
infrastructure. This toolkit creates the cluster and manages the ongoing
lifecycle. Kubernetes takes care of the applications and their peripheral
infrastructure needs using controllers and Kubernetes jobs.

| Terraform / OpenTofu     | This Toolkit                    | Kubernetes Based Control                          |
|--------------------------|---------------------------------|---------------------------------------------------|
| VPC and subnets          | Addon upgrades                  | Load Balancer Controller (ALB, NLB)               |
| NAT gateways             | Control plane upgrades          | External DNS (Route 53 Zone contents)             |
| Security groups          | Nodegroup rolling replacements  | Jobs running Terraform/OpenTofu to build stacks   |
| IAM roles and policies   | Cordon, drain, migration        |                                                   |
| Route 53 Zone creation   | Operational troubleshooting     |                                                   |
| ACM certificates         | Day-to-day cluster inspection   |                                                   |

The boundaries are clean: Terraform owns the infrastructure that the cluster
sits on. The cluster management image owns the Kubernetes-level operations
that require sequencing, judgement, and the ability to pause. Kubernetes
controllers own the application-level infrastructure that lives inside the
cluster.

None of these tools are wrong. They solve different problems. Using Terraform
for cluster lifecycle operations is like using a hammer to turn a screw — it
will get there eventually, but there is a better tool for the job.
