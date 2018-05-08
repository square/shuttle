# Workflow for Square Engineers contributing to Shuttle

Shuttle's codebase is opensouced on Github but also present on Bitbucket.
Nearly all contributions to Shuttle should be made against the Github
repository. There is a small amount of Square specific code that only exists in
the Bitbucket repository. The list of Square specific code includes:

* Sentry bug reporting
* Square specific deploy configuration
* Square specific Redis and ElasticSearch IPs
* Square SSL certificates in Docker
* Square gem mirror
* Set `no_proxy` to avoid proxying corp requests
* Kochiku CI script

### Example steps to setup Shuttle for development with Github and Bitbucket as remotes

Setup Repository:

    mkdir ~/Development/shuttle
    cd ~/Development/shuttle

    git init
    git remote add bitbucket ssh://git@git.corp.squareup.com/intl/kochiku.git
    git remote add github git@github.com:square/shuttle.git
    git fetch bitbucket
    git fetch github

    git checkout -b github-master github/master
    git checkout -b bitbucket-master bitbucket/master

Create and push a new Github branch:

    git checkout github-master
    git pull
    git checkout -b new-github-branch-name
    # ... make changes and commit them
    git push -u github HEAD

Create and push a new Bitbucket branch:

    git checkout bitbucket-master
    git pull
    git checkout -b new-bitbucket-branch-name
    # ... make changes and commit them
    git push -u bitbucket HEAD

Merge changes on Github into Bitbucket:

    git checkout bitbucket-master
    git pull
    git fetch github
    git merge --log --no-ff github/master
    git push bitbucket master
