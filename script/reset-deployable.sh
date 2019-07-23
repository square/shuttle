echo "Checking out master branch"
# first we'll checkout master branch
git checkout master

# if master branch checkout fails due to reasons like
# existing changes locally that haven't been merged
# ongoing merge/rebase/bisect
# we'll fail and exit
# otherwise, we'll delete deployable branch after checking out master
if [ $? -eq 0 ]; then
    echo "\n\nDeleting deployable branch"
    git branch -D deployable
else
    echo "\n\nLooks like something went wrong while checking out master"
    exit;
fi

# now let's create a new branch off of master called deployable
if [ $? -eq 0 ]; then
    echo "\n\nCreating new version of deployable from master"
    git checkout -b deployable
else
    echo "\n\nCouldn't delete deployable, might not exist"
    echo "\nDo you still want to create a 'deployable' branch?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) git checkout -b deployable; break;;
            No ) exit;
        esac
    done
fi

# if creating a branch succeeded, we can push it up to origin
if [ $? -eq 0 ]; then
    echo "\n\nPush latest version of deployable branch to bitbucket"
    git push -f origin deployable
fi

