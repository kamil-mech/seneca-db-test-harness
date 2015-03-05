FROM node:0.10
ADD . /
EXPOSE 44040
CMD node seneca-db-test-harness.js --db=jsonfile-store