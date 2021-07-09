# Gitlab Docker

# Run
```
run-gitlab.sh
```
## Web Admin
For the very first time you connect to http://127.0.0.1:2080, the web GUI will prompt for "root" password. You need to remember the passoword to use to login as "root/<your_password>". Otherise, you won't be able to login as "root" or use it.

# Reference
[GitLab Docker User Guide (complete)](https://docs.gitlab.com/ee/install/docker.html)

# Commandd for GIT
Note that we change the port from 22 to 2022. Hence the following commands need to use "2022" instead.

```
Command line instructions

Git global setup
git config --global user.name "Administrator"
git config --global user.email "admin@example.com"

Create a new repository
git clone http://127.0.0.1:2080/root/my-awesome.git
cd my-awesome
touch README.md
git add README.md
git commit -m "add README"
git push -u origin master

Existing folder
cd existing_folder
git init
git remote add origin http://127.0.0.1:2080/root/my-awesome.git
git add .
git commit -m "Initial commit"
git push -u origin master

Existing Git repository
cd existing_repo
git remote rename origin old-origin
git remote add origin http://gitlab.example.com/root/my-awesome.git
git push -u origin --all
git push -u origin --tags
```
