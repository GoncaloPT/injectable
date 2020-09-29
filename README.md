# injectable

Injectable is a convenient code generator for get_it. Inspired by Angular DI, Guice DI and inject.dart.

---

- [Installation](#installation)
- [Setup](#setup)
- [Registering factories](#registering-factories)
- [Registering singletons](#registering-singletons)
- [Registering asynchronous injectables](#registering-asynchronous-injectables)
- [Passing Parameters to factories](#passing-parameters-to-factories)
- [Binding abstract classes to implementations](#binding-abstract-classes-to-implementations)
- [Register under different environments](#register-under-different-environments)
- [Using named factories and static create functions](#Using-named-factories-and-static-create-functions)
- [Registering third party types](#Registering-third-party-types)
- [Auto registering](#auto-registering)
- [Micropackages support](#support-for-micro-packages)

## Installation

```yaml
dependencies:
  # add injectable to your dependencies
  injectable:
  # add get_it
  get_It:

dev_dependencies:
  # add the generator to your dev_dependencies
  injectable_generator:
  # of course build_runner is needed to run the generator
  build_runner:
```

## Setup

---

1. Create a new dart file and define a global var for your GetIt instance.
2. Define a top-level function (lets call it configureDependencies) then annotate it with @injectableInit.
3. Call the **Generated** func \$initGetIt(), or your custom initilizer name inside your configure func and pass in the getIt instance.

```dart
final getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt', // default
  preferRelativeImports: true, // default
  asExtension: false, // default
)
void configureDependencies() => $initGetIt(getIt);
```
Note: you can tell injectable what directories to generate for using the generateForDir property inside of @injectableInit.
The following example will only process files inside of the test folder.

```dart
@InjectableInit(generateForDir: ['test'])
void configureDependencies() => $initGetIt(getIt);
```


4. Call configureDependencies() in your main func before running the App.

```dart
void main() {
 configureDependencies();
 runApp(MyApp());
}
```


## Registering factories

---

All you have to do now is annotate your injectable classes with @injectable and let the generator do the work.

```dart
@injectable
class ServiceA {}

@injectable
class ServiceB {
    ServiceB(ServiceA serviceA);
}

```

### Run the generator

Use the [watch] flag to watch the files' system for edits and rebuild as necessary.

```terminal
flutter packages pub run build_runner watch
```

if you want the generator to run one time and exits use

```terminal
flutter packages pub run build_runner build
```

### Inside of the generated file

Injectable will generate the needed register functions for you

```dart
final getIt = GetIt.instance;

void $initGetIt(GetIt getIt,{String environment,EnvironmentFilter environmentFilter}) {
 final gh = GetItHelper(getIt, environment);
  gh.factory<ServiceA>(() => ServiceA());
  gh.factory<ServiceB>(ServiceA(getIt<ServiceA>()));
}
```

## Registering singletons

---

Use the @singleton or @lazySingleton to annotate your singleton classes.
Alternatively use the constructor version to pass signalsReady to getIt.registerSingleton(signalsReady)
@Singleton(signalsReady: true) >> getIt.registerSingleton(Model(), signalsReady: true)
@LazySingleton() >> getIt.registerLazySingleton(() => Model())

```dart
@singleton // or @lazySingleton
class ApiProvider {}
```

## Registering asynchronous injectables

---

Requires **GetIt >= 4.0.0**

if you are to make our instance creation async you're gonna need a static initializer method since constructors can not be asynchronous.

```dart
class ApiClient {
  static Future<ApiClient> create(Deps ...) async {
    ....
    return apiClient;
  }
}
```

Now simply annotate your class with @injectable and tell injectable to use that static initializer method as a factory method using the @factoryMethod annotation

```dart
@injectable // or lazy/singleton
class ApiClient {
@factoryMethod
  static Future<ApiClient> create(Deps ...) async {
    ....
    return apiClient;
  }
}
```

injectable will automatically register it as an asynchronous factory because the return type is a Future.
Generated Code:

```dart
factoryAsync<ApiClient>(() => ApiClient.create());
```

### Using a register module (for third party dependencies)

just wrap your instance with a future, and you're good to go

```dart
@module
abstract class RegisterModule {
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

Don't forget to call getAsync() instead of get() when resolving an async injectable

### Pre-Resolving the future

if you want to pre-await the future and register it's resolved value, annotate your async dependencies with @preResolve

```dart
@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

generated code

```dart
Future<void> $initGetIt(GetIt g, {String environment}) async {
  final gh = GetItHelper(getIt, environment);
  final registerModule = _$RegisterModule();
  final sharedPreferences = await registerModule.prefs;
  gh.factory<SharedPreferences>(() => sharedPreferences);
  ...
  }
```

as you can see this will make your initGetIt func async so be sure to **await** for it

## Passing Parameters to factories

---

Requires **GetIt >= 4.0.0**
If you're working with a class you own simply annotate your changing constructor param with @factoryParam, you can have up to two parameters **max**!

```dart
@injectable
class BackendService {
  BackendService(@factoryParam String url);
}
```

generated code

```dart
factoryParam<BackendService, String, dynamic>(
    (url, _) => BackendService(url),
  );
```

### Using a register module (for third party dependencies)
if you declare a module member as a method instead of a simple accessor, injectable will treat it as a factory method, meaning it will inject it's parameters as it would with a regular constructor.
The same way if you annotate an injected param with @factoryParam injectable will treat it as a factory param.

```dart
@module
abstract class RegisterModule {
   BackendService getService(ApiClient client, @factoryParam String url) => BackendService(client, url);
}
```

generated code

```dart
factoryParam<BackendService, String, dynamic>(
      (url, _) => registerModule.getService(g<ApiClient>(), url));
```

## Binding abstract classes to implementations

---
Use the 'as' Property inside of Injectable(as:..) to pass an abstract type that's implemented by the registered dependency

```dart
@Injectable(as: Service)
class ServiceImpl implements Service {}

// or 
@Singleton(as: Service) 
class ServiceImpl implements Service {}

// or 
@LazySingleton(as: Service) 
class ServiceImpl implements Service {}

```

Generated code for the Above example

```dart
factory<Service>(() => ServiceImpl())
```

### Binding an abstract class to multiple implementations

Since we can't use type binding to register more than one implementation, we have to use names (tags)
to register our instances or register under different environment. (we will get to that later)

```
@Named("impl1")
@Injectable(as: Service)
class ServiceImpl implements Service {}

@Named("impl2")
@Injectable(as: Service)
class ServiceImp2 implements Service {}
```

Next annotate the injected instance with @Named() right in the constructor and pass in the name of the desired implementation.

```dart
@injectable
class MyRepo {
   final Service service;
    MyRepo(@Named('impl1') this.service)
}
```

Generated code for the Above example

```dart
factory<Service>(() => ServiceImpl1(), instanceName: 'impl1')
factory<Service>(() => ServiceImpl2(), instanceName: 'impl2')

factory<MyRepo>(() => MyRepo(getIt('impl1'))
```

### Auto Tagging

Use the lower cased @named annotation to automatically assign the implementation class name to the instance name.
Then use @Named.from(Type) annotation to extract the name from the type

```dart
@named
@Injectable(as: Service)
 class ServiceImpl1 implements Service {}

@injectable
class MyRepo {
   final Service service;
    MyRepo(@Named.from(ServiceImpl1) this.service)
}
```

Generated code for the Above example

```dart
factory<Service>(() => ServiceImpl1(), instanceName: 'ServiceImpl1')
factory<MyRepo>(() => MyRepo(getIt('ServiceImpl1'))
```

## Register under different environments

---

it is possible to register different dependencies for different environments by using **@Environment('name')** annotation.
in the below example ServiceA is now only registered if we pass the environment name to \$initGetIt(environment: 'dev')

```dart
@Environment("dev")
@injectable
class ServiceA {}
```


you could also create your own environment annotations by assigning the const constructor Environment("") to a global const var.

```dart
const dev = Environment('dev');
// then just use it to annotate your classes
@dev
@injectable
class ServiceA {}
```
You can assign multiple environment names to the same class
```dart
@test
@dev
@injectable
class ServiceA {}
```
Alternatively use the env property in injectable and subs to assign environment names to your dependencies 

```dart
@Injectable(as: Service, env: [Environment.dev, Environment.test])
class RealServiceImpl implements Service {}
```

Now passing your environment to $initGetIt function will create a simple environment filter that will only validate dependencies that have no environments or one of their environments matches the given environment.
Alternatively, you can pass your own `EnvironmentFilter` to decide what dependencies to register based on their environment keys, or use one of the shipped ones
* NoEnvOrContainsAll
* NoEnvOrContainsAny
* SimpleEnvironmentFilter

## Using named factories and static create functions

---

By default, injectable will use the default constructor to build your dependencies but, you can tell injectable to use named/factory constructors or static create functions by using the @factoryMethod annotation. .

```dart
@injectable
class MyRepository {
  @factoryMethod
  MyRepository.from(Service s);
}
```

The constructor named "from" will be used when building MyRepository.

```dart
factory<MyRepository>(MyRepository.from(getIt<Service>()))
```

or annotate static create functions or factories inside of abstract classes with @factoryMethod

```dart
@injectable
abstract class Service {
  @factoryMethod
  static ServiceImpl2 create(ApiClient client) => ServiceImpl2(client);

  @factoryMethod
  factory Service.from() => ServiceImpl();
}
```

Generated code.

```dart
factory<Service>(() => Service.create(getIt<ApiClient>()))
```

## Registering third party types

---

To Register third party types, create an abstract class and annotate it with @module then add your third party types as property accessors or methods like follows:

```dart
@module
abstract class RegisterModule {
  @singleton
  ThirdPartyType get thirdPartyType;

  @prod
  @Injectable(as: ThirdPartyAbstract)
  ThirdPartyImpl get thirdPartyType;
 
}
```

### Providing custom initializers

In some cases you'd need to register instances that are asynchronous or singleton instances or just have a custom initializer and that's a bit hard for injectable to figure out on it's own, so you need to tell injectable how to initialize them;

```dart
@module
abstract class RegisterModule {

 // You can register named preemptive types like follows
  @Named("BaseUrl")
  String get baseUrl => 'My base url';
  
  // url here will be injected 
  @lazySingleton
  Dio dio(@Named('BaseUrl) String url) => Dio(BaseOptions(baseUrl: url));
 
  // same thing works for instances that's gotten asynchronous.
  // all you need to do is wrap your instance with a future and tell injectable how
  // to initialize it
  @preResolve // if you need to pre resolve the value
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
  // Also, make sure you await for your configure function before running the App.
 
}
```

if you're facing even a weirder scenario you can always register them manually in the configure function.

## Auto registering

---

Instead of annotating every single injectable class you write, it is possible to use a [Convention Based Configuration](https://en.wikipedia.org/wiki/Convention_over_configuration) to auto register your injectable classes, especially if you follow a concise naming convention.

for example, you can tell the generator to auto-register any class that ends with Service, Repository or Bloc
using a simple regex pattern
class_name_pattern: 'Service$|Repository$|Bloc\$'
To use auto-register create a file with the name **build.yaml** in the same directory as **pubspec.yaml** and add

```yaml
targets:
  $default:
    builders:
      injectable_generator:injectable_builder:
        options:
          auto_register: true
          # auto registers any class with a name matches the given pattern
          class_name_pattern:
            "Service$|Repository$|Bloc$"
            # auto registers any class inside a file with a
            # name matches the given pattern
          file_name_pattern: "_service$|_repository$|_bloc$"
```

## Support for micro packages 

Micropackage architecture ( here for more info ) is supported.
Since micro packages are actually "sub"-packages of the main source, code generation can be used to register those dependencies so they can be shared across all the projects.

Code generation works in 2 stages:
1. Inside micro package
2. In the root package

### Step 1 - Declaring a micro package module

To declare a micropackage module the following class should be created  
mymodule.dart:
```dart 
///@Micropackage annotation allows generator to be aware of the module
@MicroPackage("myModule")
class MyModule{
  //method name is not important, it should only be the 1st method and be static
  static void registerModuleDependencies(GetIt get){
    //just calls code in injection.dart, following the practice described above
    configureInjection();
  }
}
```
Example of injection.dart(this you should already have by now):
```dart
final getIt = GetIt.instance;
@InjectableInit(
  generateForDir: ['lib'],
  initializerName: 'registerMyModuleDependencies',
  asExtension: true
)
/// for local ( internal library dependency injection
void configureInjection() {
  getIt.registerMyModuleDependencies();
}
``` 

### Step 2 - Defining the root as MicroPackage

To enable micro package mode, use @MicroPackageRootInit instead of @InjectableInit in your injection.dart file.  
Also be aware that your pubspec.yaml file will have to contain your micro packages as dependency. Failing do to soo will result in an invalid injection.config.micropackage.dart file, since it will contain imports for packages not included in your dependencies.   

### Outcome

Inside the micropackage module a <module>.micropackage.json file will appear. This file should not be deleted since the root package will try to find it. 
Inside the root module  
Created files:
1. `micro_packages.json` containing the aggregation of all the found micropackage.json
1. `injection.config.micropackage.dart` contains the generated code  

Edited files:  
`injection.config.dart` => a call to MicroPackagesConfig.registerMicroModules(get) will be added 





    
 
## Problems with the generation?

---

Make sure you always **Save** your files before running the generator, if that does not work you can always try to clean and rebuild.

```terminal
flutter packages pub run build_runner clean
```

## Support the Library

- You can support the library by staring it on Github && liking it on pub or report any bugs you encounter.
- also, if you have a suggestion or think something can be implemented in a better way, open an issue and let's talk about it.
