---
title: Version control
layout: document
toc: true
---

We use Git as our versioning system.  
Location: [Github/Statoil](https://github.com/statoil)  
Prefix: `radix-`

## Workflow
[Trunk based development](https://trunkbaseddevelopment.com/)

If we want to avoid polluting main history with lots of breadcrumb commits then please rebase/squash your feature branches before creating a pull request.  
That way the master only has feature commits and not the entire commit history from every feature.

## Branching

### Master branch / trunk

We only have one main branch 'master' aka trunk. This branch will live forever and holds
our true timeline. Our CI system makes all the release builds from the master.

Rules:

* All merges to this branch should be done as a merge request and code-review within Github
* A Tag should be made for each release

### Feature branch
__May branch off from__: Master (master)  
__Must merge into__: Master  
__Naming convention__: feature/&lt;JIRA-STORY-ID&gt; (personal feature branches can be made by using credentials as prefix kjellelvis/feature/* )  
__Commit convention__: &lt;JIRA-STORY-ID&gt;: &lt;Description&gt;

A short-lived feature branch; one person over a couple of days (max) and flow through code-review & CI build (if possible) before merge back into the master.

Rules:
* Should match up to a story or a bug in our Task system (at the time Jira).
* Should preferably only contain 1 commit message, this can be accomplished by rebasing the task in interactive mode and squashing earlier commits
* Should be short lived (a couple of days max)
* Should always be merged back into the master
* Shall be deleted after merged back into master
* Shall always be merged back with a Github pull requests and code-review

## Example: feature development flow

Kari wants to implement FeatureX in AppBravo, based on on story #22 in Jira.  
The repo is cloned and ready on her dev machine.

1. Checkout and pull master branch to be sure she has latest changes  
    ```bash
    git checkout master
    git pull origin master
    ```
1. Create a feature branch from master  
   ```bash
   git checkout -b OR-22-some-feature
   ```
1. Implementation can then be commited into this new feature branch
   ```bash
   git status # See all changes
   git add <filename> # Add file to staging. Use flag -A to add deleted files.
   git status # To verify that you have staged what you think you have staged
   git commit -m "OR-22: Added X to Y, behold Z!" # Use commit convention
   ```
1. Push commits to origin to avoid losing work every now and then
   ```bash
   push origin OR-22-some-feature
   ```
1. When implementation is complete and ready for code review then rebase and squash commits before creating a pull request
   ```bash
   git checkout OR-22-some-feature
   git fetch origin master
   git rebase -i origin/master
   git push -f origin OR-22-some-feature
   ```
1. Create a pull request on github
1. Review ok then merge into master and delete feature branch.  
   ```bash
   git branch -D OR-22-some-feature # Delete local branch. To delete remote then just push the delete button as part of the pull request dialog.
   ```

## Example: Tag a release

Find the latest commit that is after all features that make up the release in master branch.  
Find the SHA ID of the commit by using `git log` or in browser.
Tag name should be a version, ex "v1.2.0".
```bash
git checkout master
git pull origin # Get all changes
git log # Find commit SHA ID
git tag -a <tagname> <SHA-of-the-commit> -m "Added feature x"
git push origin <tagname>
```

## Example: Delete a tag
```bash
# Delete local tag
git tag --delete <tagname>
# Delete remote tag
git push --delete origin <tagname>
```

## Versioning
Use [semantic versioning](https://semver.org/) until the release cadence gets so fast it is no longer feasible.  

Syntax: `v<MAJOR>.<MINOR>.<PATCH>`  
Example: "v1.9.0"

_Summary_  
Given a version number MAJOR.MINOR.PATCH, increment the:  

MAJOR version when you make incompatible API changes,  
MINOR version when you add functionality in a backwards-compatible manner, and  
PATCH version when you make backwards-compatible bug fixes.  



## Useful Git Commands

### Delete matching local branches
```bash
# Delete matching local branches
git branch | cut -c3- | egrep "^feature/" | xargs git branch -D  
```

### Rename branch
If you have named a branch incorrectly AND pushed this to the remote repository follow these steps before any other developers get a chance to jump on you and give you shit for not correctly following naming conventions.

1. Rename your local branch
   If you are on the branch you want to rename:
   ```bash
   git branch -m new-name
   ```  
   
   If you are on a different branch:
   ```bash
   git branch -m old-name new-name
   ```
2. Delete the old-name remote branch and push the new-name local branch
   ```bash
   git push origin :old-name new-name
   ```
3. Reset the upstream branch for the new-name local branch  
   Switch to the branch and then:
   ```bash
   git push origin -u new-name
   ```  
   
## External resources
* [http://ohshitgit.com/](http://ohshitgit.com/)
