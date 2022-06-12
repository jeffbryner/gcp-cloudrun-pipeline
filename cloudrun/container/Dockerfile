# from https://github.com/IBM/CodeEngine/tree/main/hello
FROM icr.io/codeengine/node:12-alpine
RUN npm install
COPY server.js .
EXPOSE ${PORT}
CMD [ "node", "server.js" ]