
from dataclasses import dataclass
import logging

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="clients/{blobname}", methods=[func.HttpMethod.POST])
@app.blob_output(arg_name="outputblob", connection="AzureWebJobsStorage", path="clients/{blobname}")
def client_post(req: func.HttpRequest, outputblob: func.Out[bytes]) -> func.HttpResponse:
    try:
        blobname = req.route_params.get("blobname")
        content = req.get_body()
        outputblob.set(content)
        return func.HttpResponse(f"Stored blob: {blobname}", status_code=200)
    except Exception as e:
        return func.HttpResponse(f"Error storing blob: {str(e)}", status_code=500)


@app.route(route="clients/{blobname}", methods=[func.HttpMethod.GET])
@app.blob_input(arg_name="inputblob", connection="AzureWebJobsStorage", path="clients/{blobname}")
def client_get(req: func.HttpRequest, inputblob: func.InputStream) -> func.HttpResponse:
    try:
        blobname = req.route_params.get("blobname")
        content = inputblob.read().decode("utf-8")
        return func.HttpResponse(content, status_code=200)
    except Exception as e:
        return func.HttpResponse(f"Blob '{blobname}' not found.", status_code=404)


@app.route(route="log", methods=[func.HttpMethod.POST])
def log_info(req: func.HttpRequest) -> func.HttpResponse:
    content = req.get_body()
    logging.info("Log Info: %s", content)
    return func.HttpResponse(status_code=200)

