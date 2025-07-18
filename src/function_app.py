
from dataclasses import dataclass
import json
import logging

import azure.functions as func
#import azurefunctions.extensions.bindings.blob as blob

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Constants for the Azure Blob Storage container, file, and blob path
_SNIPPET_NAME_PROPERTY_NAME = "snippetname"
_SNIPPET_PROPERTY_NAME = "snippet"
_BLOB_PATH = "snippets/{mcptoolargs." + _SNIPPET_NAME_PROPERTY_NAME + "}.json"


@dataclass
class ToolProperty:
    propertyName: str
    propertyType: str
    description: str


# Define the tool properties using the ToolProperty class
tool_properties_save_snippets_object = [
    ToolProperty(_SNIPPET_NAME_PROPERTY_NAME, "string", "The name of the snippet."),
    ToolProperty(_SNIPPET_PROPERTY_NAME, "string", "The content of the snippet."),
]

tool_properties_get_snippets_object = [ToolProperty(_SNIPPET_NAME_PROPERTY_NAME, "string", "The name of the snippet.")]

# Convert the tool properties to JSON
tool_properties_save_snippets_json = json.dumps([prop.__dict__ for prop in tool_properties_save_snippets_object])
tool_properties_get_snippets_json = json.dumps([prop.__dict__ for prop in tool_properties_get_snippets_object])


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="hello_mcp",
    description="Hello world.",
    toolProperties="[]",
)
def hello_mcp(context) -> str:
    """
    A simple function that returns a greeting message.

    Args:
        context: The trigger context (not used in this function).

    Returns:
        str: A greeting message.
    """
    return "Hello I am MCPTool!"


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="get_snippet",
    description="Retrieve a snippet by name.",
    toolProperties=tool_properties_get_snippets_json,
)
@app.generic_input_binding(arg_name="file", type="blob", connection="AzureWebJobsStorage", path=_BLOB_PATH)
def snippet_get(file: func.InputStream, context) -> str:
    """
    Retrieves a snippet by name from Azure Blob Storage.

    Args:
        file (func.InputStream): The input binding to read the snippet from Azure Blob Storage.
        context: The trigger context containing the input arguments.

    Returns:
        str: The content of the snippet or an error message.
    """
    snippet_content = file.read().decode("utf-8")
    logging.info("Retrieved snippet: %s", snippet_content)
    return snippet_content


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="save_snippet",
    description="Save a snippet with a name.",
    toolProperties=tool_properties_save_snippets_json,
)
@app.generic_output_binding(arg_name="file", type="blob", connection="AzureWebJobsStorage", path=_BLOB_PATH)
def snippet_save(file: func.Out[str], context) -> str:
    content = json.loads(context)
    if "arguments" not in content:
        return "No arguments provided"

    snippet_name_from_args = content["arguments"].get(_SNIPPET_NAME_PROPERTY_NAME)
    snippet_content_from_args = content["arguments"].get(_SNIPPET_PROPERTY_NAME)

    if not snippet_name_from_args:
        return "No snippet name provided"

    if not snippet_content_from_args:
        return "No snippet content provided"

    file.set(snippet_content_from_args)
    logging.info("Saved snippet: %s", snippet_content_from_args)
    return f"Snippet '{snippet_content_from_args}' saved successfully"


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

