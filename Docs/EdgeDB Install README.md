# Building a TODO API with EdgeDB and ASP.Net Core

For this tutorial we're going to build a simple TODO API using the EdgeDB as a database. We'll start by creating a new asp.net core project.

C:\repos\edgedb-projects>

```console
$ dotnet new webapi -n EdgeDB.Examples.ExampleTODOApi
```

Once we have our ASP.Net Core project, we can add the EdgeDB.Net driver to our project as a reference.

C:\repos\edgedb-projects> cd EdgeDB.Examples.ExampleTODOApi

#### Myget
```console
$ dotnet add package EdgeDB.Net.Driver -Source https://www.myget.org/F/edgedb-net/api/v3/index.json
```

#### NuGet
```console
$ dotnet add package EdgeDB.Net.Driver
```

## Initializing EdgeDB

Lets now create our EdgeDB instance for this API, for this we're going to use the `edgedb` cli.

### Installing the CLI

#### Linux or macOS
```console
$ curl --proto '=https' --tlsv1.2 -sSf https://sh.edgedb.com | sh
```

#### Windows Powershell
```ps
PS> iwr https://ps1.edgedb.com -useb | iex
```

Then verify that the CLI is installed and available with the `edgedb --version` command. If you get a `Command not found` error, you may need to open a new terminal window before the `edgedb` command is available.

Once the CLI is installed, we can initialize a project for our TODO api. You can read more about [EdgeDB projects here.](https://www.edgedb.com/docs/guides/projects)

```console
$ edgedb project init
```

This command will take you through an interactive setup process which looks like the following:

```
No `edgedb.toml` found in `~/example` or above

Do you want to initialize a new project? [Y/n]
> Y

Specify the name of EdgeDB instance to use with this project [default:
example]:
> dotnet-example

Checking EdgeDB versions...
Specify the version of EdgeDB to use with this project [default: 1.x]:
> 1.x

Do you want to start instance automatically on login? [y/n]
> y
┌─────────────────────┬──────────────────────────────────────────────┐
│ Project directory   │ ~/example                                    │
│ Project config      │ ~/example/edgedb.toml                        │
│ Schema dir (empty)  │ ~/example/dbschema                           │
│ Installation method │ portable package                             │
│ Start configuration │ manual                                       │
│ Version             │ 1.x                                          │
│ Instance name       │ dotnet-example                               │
└─────────────────────┴──────────────────────────────────────────────┘
Initializing EdgeDB instance...
Applying migrations...
Everything is up to date. Revision initial.
Project initialized.
```

## Defining the schema

We now have a edgedb project linked to our TODO API, lets next add our schema we will use for our API.

Our database schema file is located in the `dbschema` directory,
by default the name of the file is `default.esdl` and it looks like this

```d
module default {

}
```

Lets add a type called `TODO`
```diff
module default {
+  type TODO {
+
+  }
}
```

Our todo structure will consist of four feilds:
`title`, `description`, `date_created`, and `state`.

Our `state` field will be the state of the todo ex: `Not Started`, `In Progress`, `Completed`,

for this we will have to define our own enum type.

You can read more about [enums here.](https://www.edgedb.com/docs/datamodel/primitives#enums).

```diff
module default {
+  scalar type State extending enum<NotStarted, InProgress, Complete>;

  type TODO {

  }
}
```

Lets now finally add our properties to our type.

```diff 
module default {
  scalar type State extending enum<NotStarted, InProgress, Complete>;

  type TODO {
+    required property title -> str;
+    required property description -> str;
+    required property date_created -> std::datetime {
+      default := std::datetime_current();
+    }
+    required property state -> State;
  }
}
```

Our datetime property will automatically be set to the current date and time when the todo is created.

Lets now run the migration commands to apply the schema change to the database.
```console
$ edgedb migration create
```

## Defining our C# type

Lets now define our C# type that will represent the `TODO` type in the schema file.
We can do this with a simple class like so:

```cs
public class TODOModel
{
    public class TODOModel
    {
        public string? Title { get; set; }

        public string? Description { get; set; }

        public DateTimeOffset DateCreated { get; set; }

        public TODOState State { get; set; }
    }

    public enum TODOState
    {
        NotStarted,
        InProgress,
        Complete
    }
}
```

We now need to mark this type as a valid type to use when deserializing,
we can do this with the `EdgeDbType` attribute

```diff
+[EdgeDBType]
public class TODOModel
```

One thing to note is our property names, they're different from the ones in the schema file.
We can use the `EdgeDBProperty` attribute to map the schema file property names to the C# properties.

```diff
public class TODOModel
{
    public class TODOModel
    {
+        [EdgeDBProperty("title")]
        public string? Title { get; set; }

+        [EdgeDBProperty("description")]
        public string? Description { get; set; }

+        [EdgeDBProperty("date_created")]
        public DateTimeOffset DateCreated { get; set; }

+        [EdgeDBProperty("state")]
        public TODOState State { get; set; }
    }

    public enum TODOState
    {
        NotStarted,
        InProgress,
        Complete
    }
}
```

We should also add attributes for serializing this class to JSON as we're going to be returning it from our API.

```diff
    public class TODOModel
    {
+        [JsonPropertyName("title")]
        [EdgeDBProperty("title")]
        public string? Title { get; set; }

+        [JsonPropertyName("description")]
        [EdgeDBProperty("description")]
        public string? Description { get; set; }

+        [JsonPropertyName("date_created")]
        [EdgeDBProperty("date_created")]
        public DateTimeOffset DateCreated { get; set; }

+        [JsonPropertyName("state")]
        [EdgeDBProperty("state")]
        public TODOState State { get; set; }
    }

    public enum TODOState
    {
        NotStarted,
        InProgress,
        Complete
    }
}
```

Our type is now mapped to the edgedb type `TODO` and we can use it to deserialize query data.


## Setting up EdgeDB.Net in our project

Lets now setup an edgedb client we can use for our project,
this is relatively simple for us as we can use
[Dependency Injection](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-6.0).

Lets head over to our `Program.cs` file and add the following:
```diff
+ using EdgeDB;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

+ builder.Services.AddEdgeDB();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
```

And thats it! We now have a `EdgeDBClient` singleton within our service collection.

## Defining our API routes

Lets create a new controller for our API called `TODOController` and have DI inject the `EdgeDBClient` into the constructor.

```diff
+using Microsoft.AspNetCore.Mvc;
+using System.ComponentModel.DataAnnotations;
+
+namespace EdgeDB.Examples.ExampleTODOApi.Controllers
+{
+    public class TODOController : Controller
+    {
+        private readonly EdgeDBClient _client;
+
+        public TODOController(EdgeDBClient client)
+        {
+            _client = client;
+        }
+    }
+} 
```

Lets start with the `GET` route for fetching all of our todos.

```diff
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace EdgeDB.Examples.ExampleTODOApi.Controllers
{
    public class TODOController : Controller
    {
        private readonly EdgeDBClient _client;

        public TODOController(EdgeDBClient client)
        {
            _client = client;
        }
+
+        [HttpGet("/todos")]
+        public async Task<IActionResult> GetTODOs()
+        {
+            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state, date_created }").ConfigureAwait(false);
+
+            return Ok(todos);
+        }
    }
} 
```

We use the `QueryAsync<T>` method on the client as our query will return 0 or many results,
we also pass in our `TODOModel` class from earlier to deserialize the results as that class.
Finally, we return out the collection of todos as a JSON response.

### Testing the GET route

We can test the route with the
[swagger interface](https://docs.microsoft.com/en-us/aspnet/core/tutorials/getting-started-with-swashbuckle?view=aspnetcore-6.0&tabs=visual-studio)
by running our project and then clicking on the `GET /todos` route.

We can see the return result of our `GET` route is a 200 with an empty JSON array:
```json
GET /todos

[]
```

This means our api is functional. Lets now add a route for creating a new todo.

```diff
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace EdgeDB.Examples.ExampleTODOApi.Controllers
{
    public class TODOController : Controller
    {
        private readonly EdgeDBClient _client;

        public TODOController(EdgeDBClient client)
        {
            _client = client;
        }

        [HttpGet("/todos")]
        public async Task<IActionResult> GetTODOs()
        {
            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state, date_created }").ConfigureAwait(false);

            return Ok(todos);
        }
+
+        [HttpPost("/todos")]
+        public async Task<IActionResult> CreateTODO([FromBody]TODOModel todo)
+        {
+            // validate request
+            if (string.IsNullOrEmpty(todo.Title) || string.IsNullOrEmpty(todo.Description))
+                return BadRequest();
+
+            var query = "insert TODO { title := <str>$title, description := <str>$description, state := <State>$state }";
+            await _client.ExecuteAsync(query, new Dictionary<string, object?>
+            {
+                {"title", todo.Title},
+                {"description", todo.Description},
+                {"state", todo.State }
+            });
+
+            return NoContent();
+        }
    }
} 
```

Our new route will validate the todo we're passing in and if it's valid, we'll insert it into the database.
One thing to note here is we're using the `Dictionary<string, object?>` to pass in our parameters.
This is to prevent any query injection attacks.
You can learn more about [EdgeQL parameters here.](https://www.edgedb.com/docs/edgeql/parameters).


### Testing the POST route

Using the Swagger UI, we will run our route with this post body
```json
POST /todos

{
  "title": "Hello",
  "description": "Wolrd!",
  "state": 0
}
```

```json  John Trying
{
  "title": "string 15:59",
  "description": "John Tst string 9/26",
  "state": 2
}
```

We don't include the date as that property is generated by the database, and should not be controlled by the user.

We get a 204 meaning our route was successful, lets now call the `GET` route to see our newly created todo:
```json
GET /todos

[
  {
    "title": "Hello",
    "description": "Wolrd!",
    "date_created": "2022-06-13T22:47:06.448927+00:00",
    "state": 0
  }
]
```

To see the EdgeDB contents, From command prompt typed in:
edgedb ui

to bring up the EdgeDB www interface :
http://localhost:10701/ui/edgedb/editor

from the Query Editor typed in (luckily it autocompletes all the field names) :
SELECT TODO { date_created, description, id, state, title };


Here we can see our todo was created successfully as well as returned from our api successfully. Lets next add a route to delete todos.

```diff
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace EdgeDB.Examples.ExampleTODOApi.Controllers
{
    public class TODOController : Controller
    {
        private readonly EdgeDBClient _client;

        public TODOController(EdgeDBClient client)
        {
            _client = client;
        }

        [HttpGet("/todos")]
        public async Task<IActionResult> GetTODOs()
        {
            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state, date_created }").ConfigureAwait(false);

            return Ok(todos);
        }

        [HttpPost("/todos")]
        public async Task<IActionResult> CreateTODO([FromBody]TODOModel todo)
        {
            // validate request
            if (string.IsNullOrEmpty(todo.Title) || string.IsNullOrEmpty(todo.Description))
                return BadRequest();

            var query = "insert TODO { title := <str>$title, description := <str>$description, state := <State>$state }";
            await _client.ExecuteAsync(query, new Dictionary<string, object?>
            {
                {"title", todo.Title},
                {"description", todo.Description},
                {"state", todo.State }
            });

            return NoContent();
        }
+
+        [HttpDelete("/todos")]
+        public async Task<IActionResult> DeleteTODO([FromQuery, Required]string title)
+        {
+            var result = await _client.QueryAsync<object>("delete TODO filter .title = <str>$title", new Dictionary<string, object?> { { "title", title } });
+            
+            return result.Count > 0 ? NoContent() : NotFound();
+        }
    }
} 
```

{
  "title": "string 444",
  "description": "string 9/26 17:40",
  "state": 1
}

Our delete route will take in a title as a query parameter and delete the todo with that title. Note that we're using the `QueryAsync` method here with an `object` as the return type so we can count how many todos were deleted, then returning 204 if we deleted at least one todo, and 404 if we didn't.

## Testing the DELETE route

Using the Swagger UI, we will run our route with this query parameter
```
?title=Hello
```

Once we execute this we see we got a 204 meaning our route was successful, lets now call the `GET` route to see if our todo still exists.
```json
GET /todos

[]
```

If we run the exact same `DELETE` request again we get a 404 as the todo we were trying to delete no longer exists.

Lets finally add a route to update a todos state.

```diff
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace EdgeDB.Examples.ExampleTODOApi.Controllers
{
    public class TODOController : Controller
    {
        private readonly EdgeDBClient _client;

        public TODOController(EdgeDBClient client)
        {
            _client = client;
        }

        [HttpGet("/todos")]
        public async Task<IActionResult> GetTODOs()
        {
            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state, date_created }").ConfigureAwait(false);

            return Ok(todos);
        }

        [HttpPost("/todos")]
        public async Task<IActionResult> CreateTODO([FromBody]TODOModel todo)
        {
            // validate request
            if (string.IsNullOrEmpty(todo.Title) || string.IsNullOrEmpty(todo.Description))
                return BadRequest();

            var query = "insert TODO { title := <str>$title, description := <str>$description, state := <State>$state }";
            await _client.ExecuteAsync(query, new Dictionary<string, object?>
            {
                {"title", todo.Title},
                {"description", todo.Description},
                {"state", todo.State }
            });

            return NoContent();
        }

        [HttpDelete("/todos")]
        public async Task<IActionResult> DeleteTODO([FromQuery, Required]string title)
        {
            var result = await _client.QueryAsync<object>("delete TODO filter .title = <str>$title", new Dictionary<string, object?> { { "title", title } });
            
            return result.Count > 0 ? NoContent() : NotFound();
        }

+        [HttpPatch("/todos")]
+        public async Task<IActionResult> UpdateTODO([FromQuery, Required] string title, [FromQuery, Required]TODOState state)
+        {
+            var result = await _client.QueryAsync<object>("update TODO filter .title = <str>$title set { state := <State>$state }", new Dictionary<string, object?> 
+            { 
+                { "title", title } ,
+                { "state", state }
+            });
+            return result.Count > 0 ? NoContent() : NotFound();
+        }
    }
} 
```

This route will take in a title and a state as query parameters and update the todo with that title to the given state.

## Testing the PATCH route

Lets run the same `POST` request we did earlier to create another todo, then lets call `PATCH` to update the state of our todo.

```
PATCH /todos

?title=Hello$state=1
```

Running this we get a 204 meaning our route was successful, lets now call the `GET` route to see our todo and check if its state was updated
```json
GET /todos

[
  {
    "title": "Hello",
    "description": "Wolrd!",
    "date_created": "2022-06-13T22:56:15.269224+00:00",
    "state": 1
  }
]
```

As we can see our state was updated successfully.

# Conclusion

This tutorial has covered the basics of how to use the EdgeDB client to query, update and delete data. Feel free to expirement with the source code [here](https://github.com/quinchs/EdgeDB.Net/tree/dev/examples/EdgeDB.Examples.ExampleTODOApi).


## Trying to add checking for duplicate before POSTing

For code:

            // Looking for duplicate title before posting to DB
            var todos = await _client.QueryAsync<TODOModel>("select TODO filter .title = <str>$title { title, description }").ConfigureAwait(false);
            if (todos.Count() > 1)
                return BadRequest("That Title already exists.");


EdgeDB returns this error:
QueryError: missing a type cast before the parameter
   |
 1 | select TODO filter .title = <str>$title { title, description }
 
 
 With this input:
{
  "title": "Hello",
  "description": "duplicate string 9/26 20:09",
  "state": 0
}
            // Looking for duplicate title before posting to DB
            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description } filter .title = <str>$title ").ConfigureAwait(false);
            if (todos.Count() > 1)
                return BadRequest("That Title already exists.");


EdgeDB flips a bit and dies :

EdgeDB.EdgeDBException: Failed to execute query

 ---> System.ArgumentException: Expected dynamic object or array but got null

   at EdgeDB.Binary.Codecs.ObjectCodec.Serialize(PacketWriter& writer, Object value, CodecContext context)

   at EdgeDB.Binary.Codecs.ObjectCodec.SerializeArguments(PacketWriter& writer, Object value, CodecContext context)

   at EdgeDB.Binary.Codecs.BaseArgumentCodec`1.EdgeDB.Binary.Codecs.IArgumentCodec.SerializeArguments(PacketWriter& writer, Object value, CodecContext context)

   at EdgeDB.CodecExtensions.SerializeArguments(IArgumentCodec codec, EdgeDBBinaryClient client, Object value)

   at EdgeDB.EdgeDBBinaryClient.ExecuteInternalAsync(String query, IDictionary`2 args, Nullable`1 cardinality, Nullable`1 capabilities, IOFormat format, Boolean isRetry, Boolean implicitTypeName, CancellationToken token)

   --- End of inner exception stack trace ---

   at EdgeDB.EdgeDBBinaryClient.ExecuteInternalAsync(String query, IDictionary`2 args, Nullable`1 cardinality, Nullable`1 capabilities, IOFormat format, Boolean isRetry, Boolean implicitTypeName, CancellationToken token)

   at EdgeDB.EdgeDBBinaryClient.QueryAsync[TResult](String query, IDictionary`2 args, Nullable`1 capabilities, CancellationToken token)

   at EdgeDB.EdgeDBClient.QueryAsync[TResult](String query, IDictionary`2 args, Nullable`1 capabilities, CancellationToken token)

   at EdgeDB.EdgeDBClient.QueryAsync[TResult](String query, IDictionary`2 args, Nullable`1 capabilities, CancellationToken token)

   at EdgeDB.Examples.ExampleTODOApi.Controllers.TODOController.CreateTODO(TODOModel todo) in C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi\Controllers\TODOController.cs:line 32

   at Microsoft.AspNetCore.Mvc.Infrastructure.ActionMethodExecutor.TaskOfIActionResultExecutor.Execute(ActionContext actionContext, IActionResultTypeMapper mapper, ObjectMethodExecutor executor, Object controller, Object[] arguments)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.<InvokeActionMethodAsync>g__Awaited|12_0(ControllerActionInvoker invoker, ValueTask`1 actionResultValueTask)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.<InvokeNextActionFilterAsync>g__Awaited|10_0(ControllerActionInvoker invoker, Task lastTask, State next, Scope scope, Object state, Boolean isCompleted)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Rethrow(ActionExecutedContextSealed context)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.InvokeInnerFilterAsync()

--- End of stack trace from previous location ---

   at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeFilterPipelineAsync>g__Awaited|20_0(ResourceInvoker invoker, Task lastTask, State next, Scope scope, Object state, Boolean isCompleted)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)

   at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)

   at Microsoft.AspNetCore.Routing.EndpointMiddleware.<Invoke>g__AwaitRequestTask|6_0(Endpoint endpoint, Task requestTask, ILogger logger)

   at Microsoft.AspNetCore.Authorization.AuthorizationMiddleware.Invoke(HttpContext context)

   at Swashbuckle.AspNetCore.SwaggerUI.SwaggerUIMiddleware.Invoke(HttpContext httpContext)

   at Swashbuckle.AspNetCore.Swagger.SwaggerMiddleware.Invoke(HttpContext httpContext, ISwaggerProvider swaggerProvider)

   at Microsoft.AspNetCore.Authentication.AuthenticationMiddleware.Invoke(HttpContext context)

   at Microsoft.AspNetCore.Diagnostics.DeveloperExceptionPageMiddlewareImpl.Invoke(HttpContext context)



HEADERS

=======

Accept: */*

Host: localhost:7093

User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0

Accept-Encoding: gzip, deflate, br

Accept-Language: en-US,en;q=0.5

Content-Type: application/json

Origin: https://localhost:7093

Referer: https://localhost:7093/swagger/index.html

TE: trailers

Content-Length: 73

sec-fetch-dest: empty

sec-fetch-mode: cors

sec-fetch-site: same-origin


 With this input:
{
  "title": "Hello",
  "description": "duplicate string 9/26 20:18",
  "state": 0
}

QueryError: missing a type cast before the parameter
   |
 1 | select TODO { title, description, state } filter .title = <str>$todo.title
   |                                                                ^^^^^
 
 
EdgeQLSyntaxError: Unexpected ':'
   |
 1 | select TODO { title, description, state } filter .title = <str>$todo:title
 
 
EdgeQLSyntaxError: 
   |
 1 | select TODO { title, description, state } filter .title = <str>$todo.Title
 
 
QueryError: missing a type cast before the parameter
   |
 1 | select TODO { title, description, state } filter .title = <str>$todo.Title
   |                                                                ^^^^^

InvalidReferenceError: object type or alias 'default::Title' does not exist
   |
 1 | select TODO { title, description, state } filter .title = <str>Title
   |                                                                ^^^^^
Hint: did you mean '.title'?


InvalidReferenceError: object type or alias 'default::title' does not exist
   |
 1 | select TODO { title, description, state } filter .title = <str>title
   |                                                                ^^^^^
Hint: did you mean '.title'?


InvalidReferenceError: object type or alias 'default::todo' does not exist
   |
 1 | select TODO { title, description, state } filter .title = todo.title
   |                                                           ^^^^

InvalidReferenceError: object type or alias 'default::todo' does not exist
   |
 1 | select TODO { title, description, state } filter .title = todo.title
   |                                                           ^^^^

 With this input:
{
  "title": "Hello",
  "description": "duplicate string 9/27 08:38",
  "state": 1
}

InvalidReferenceError: object type or alias 'default::todo' does not exist
   |
 1 | select TODO { title, description, state } filter .title = <str>todo.title
   |                                                                ^^^^


QueryError: missing a type cast before the parameter
   |
 1 | select TODO { title, description, state } filter .title = <str>$todo.title
   |                                                                ^^^^^


I can't figure out where Console.Write is outputing?

I think this is working
            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state } filter .title = '{todo.Title}'").ConfigureAwait(false);

but it's not finding the other Hello titles.

            if (todos.Count() > 1)
                return BadRequest("That Title already exists.");


I just saw that VS is running a command prompt which has the output:
Console.Write("todo.Title {todo.Title} todo.Description {todo.Description}");

ChatGPT manual steps:
Open up a command prompt
cd to project base
dotnet run
Open a browser manually and run:
https://localhost:7093/swagger/index.html

didn't seem to work several times. (look up in project where Port is ...? 7093 ? )
Then once it started to bring up the Swagger www UI but then didn't complete.

tried the ChatGPT default URL
https://localhost:5001/swagger/index.html
didn't work at all.


 With this input:
{
  "title": "Hello",
  "description": "duplicate string 9/27 09:12",
  "state": 1
}

            var todos = await _client.QueryAsync<TODOModel>("select TODO { title, description, state } filter .title = '{todo.Title}'").ConfigureAwait(false);


todo.Title {todo.Title} todo.Description {todo.Description}

todo.Title Hello todo.Description duplicate string 9/27 08:55

Updated schema C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi\dbschema\default.esdl
to have 
unique (exculsive) title's 
minimum title length of 8 characters.

        required property title -> str {
            constraint exclusive;
            constraint min_len_value(8);
        }


PS C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi> edgedb migration create
Connecting to EdgeDB instance at localhost:10701...
did you alter property 'title' of object type 'default::TODO'? [y,n,l,c,b,s,q,?]
> y
Created C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi\dbschema\migrations\00002.edgeql, id: m1yem2i2f6e2v6occd5x5dhmcyxhayokdbsvtk64rmceypp2okpvvq

PS C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi> edgedb migration apply
Connecting to EdgeDB instance at localhost:10701...
edgedb error: ConstraintViolationError: title violates exclusivity constraint
  Detail: property 'title' of object type 'default::TODO' violates exclusivity constraint
edgedb error: error in one of the migrations

In http://localhost:10701/ui/edgedb/editor

DELETE TODO FILTER .title LIKE 'Hello'
      AND .description LIKE 'duplicate%';


SELECT TODO { id, title, description, state, date_created }
FILTER .title LIKE 'Hello 09:15'
  AND datetime_get(.date_created, 'hour') = 6 
  AND datetime_get(.date_created, 'minutes') IN { 12, 13 };

DELETE TODO
FILTER .title LIKE 'Hello 09:15'
  AND datetime_get(.date_created, 'hour') = 6 
  AND datetime_get(.date_created, 'minutes') IN { 12 };


PS C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi> edgedb migration apply
Connecting to EdgeDB instance at localhost:10701...
edgedb error: ConstraintViolationError: title must be no shorter than 8 characters.
  Detail: `property 'title' of object type 'default`::`TODO'` must be no shorter than 8 characters.
edgedb error: error in one of the migrations

UPDATE TODO FILTER .title = 'Hello' SET { title := "Hello 78" }
UPDATE TODO FILTER .title = 'Hello 6' SET { title := "Hello 68" }

PS C:\repos\edgedb-projects\EdgeDB.Examples.ExampleTODOApi> edgedb migration apply
Connecting to EdgeDB instance at localhost:10701...
Applied m1yem2i2f6e2v6occd5x5dhmcyxhayokdbsvtk64rmceypp2okpvvq (00002.edgeql)

{
  "title": "Hello",
  "description": "duplicate string 9/27 09:12",
  "state": 1
}

curl -X 'POST' \
  'https://localhost:7093/todos' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "title": "Hello",
  "description": "duplicate string 9/27 11:30",
  "state": 2

}'

Response body
ConstraintViolationError: title must be no shorter than 8 characters.

HEADERS
=======

Accept: */*
Host: localhost:7093
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0
Accept-Encoding: gzip, deflate, br
Accept-Language: en-US,en;q=0.5
Content-Type: application/json
Origin: https://localhost:7093
Referer: https://localhost:7093/swagger/index.html
TE: trailers
Content-Length: 85
sec-fetch-dest: empty
sec-fetch-mode: cors
sec-fetch-site: same-origin


Response headers

 content-type: text/plain; charset=utf-8  date: Wed,27 Sep 2023 18:30:18 GMT  server: Kestrel  x-firefox-spdy: h2 
 
{
  "title": "Hello 68",
  "description": "duplicate string 9/27 11:30",
  "state": 3
}

Response 500 - InvalidValueError: invalid input value for enum 'default::State': "3"


{
  "title": "Hello 68",
  "description": "duplicate string 9/27 11:30",
  "state": 0
}

Response 500 - ConstraintViolationError: title violates exclusivity constraint


{
  "title": "Hello 88",
  "description": "duplicate string 9/27 11:34",
  "state": 0
}

Response headers for Code 204 response

 date: Wed,27 Sep 2023 18:34:22 GMT  server: Kestrel  x-firefox-spdy: h2 

{
  "title": "Hello 88",
  "description": "duplicate string 9/27 11:35",
  "state": 1
}

Response 500 - ConstraintViolationError: title violates exclusivity constraint

{
  "title": "Hello 99",
  "description": "duplicate string 9/27 11:35",
  "state": 4
}


Error: response status is 500

InvalidValueError: invalid input value for enum 'default::State': "4"

{
  "title": "Hello 99",
  "description": "duplicate string 9/27 11:38",
  "state": 1
}

Response headers for Code 204 response

 content-type: text/plain; charset=utf-8  date: Wed,27 Sep 2023 18:38:20 GMT  server: Kestrel  x-firefox-spdy: h2 

