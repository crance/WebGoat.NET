# 🛡️ WebGoat.NET AppSec Demo

> Based on [WebGoat.NET by Jerry Hoff](https://github.com/jerryhoff/WebGoat.NET). This independent fork adds CI/CD and AppSec tooling for demonstration purposes.

> [!WARNING]
> This application is intentionally vulnerable. Run it only in an isolated lab environment and never expose it to the internet.

## What This Demo Shows

This repository demonstrates how AppSec capabilities can be introduced into the delivery pipeline of a legacy .NET Framework application:

- Building a legacy .NET Framework application with a current CI runner
- Performing static application security testing with SAST tooling
- Identifying third-party component risk through software composition analysis

## AppSec Coverage

| Capability | Tooling and Evidence |
| --- | --- |
| Build validation | [![Build](https://img.shields.io/github/actions/workflow/status/crance/WebGoat.NET/build.yml?branch=appsec-demo&label=Build&logo=github)](https://github.com/crance/WebGoat.NET/actions/workflows/build.yml) |
| Static application security testing | [![Fortify on Demand](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fams.fortify.com%2Flogin&search=class%3D%22version%22%3E(%5Cd%2B%5C.%5Cd%2B)%3C&replace=%241&label=Fortify%20on%20Demand&color=blue&cacheSeconds=3600)](https://www.microfocus.com/documentation/fortify-on-demand/) [![Fortify SAST](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcrance%2FWebGoat.NET%2Fappsec-demo%2Fappsec%2Fversions.json&query=%24.fortify.sast&label=Fortify%20SAST&color=blue)](https://www.microfocus.com/documentation/fortify-static-code-analyzer-and-tools/) [![ScanCentral Client](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcrance%2FWebGoat.NET%2Fappsec-demo%2Fappsec%2Fversions.json&query=%24.fortify.scancentral_client&label=ScanCentral%20Client&color=purple)](https://github.com/fortify/tool-definitions/blob/main/v1/sc-client.yaml) |
| Software composition analysis | [![Sonatype IQ CLI](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcrance%2FWebGoat.NET%2Fappsec-demo%2Fappsec%2Fversions.json&query=%24.sonatype.iq_cli&label=Sonatype%20IQ%20CLI&color=purple)](https://help.sonatype.com/en/download-and-compatibility.html#sonatype-iq-cli-162264) |
| Application baseline | ![.NET Framework](https://img.shields.io/badge/dynamic/xml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcrance%2FWebGoat.NET%2Fappsec-demo%2FWebGoat%2FWebGoat.NET.csproj&query=%2F%2F*%5Blocal-name()%3D'TargetFrameworkVersion'%5D%2Ftext()&label=.NET%20Framework&color=512BD4) ![MSBuild](https://img.shields.io/badge/dynamic/xml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcrance%2FWebGoat.NET%2Fappsec-demo%2FWebGoat%2FWebGoat.NET.csproj&query=%2F*%5Blocal-name()%3D'Project'%5D%2F%40ToolsVersion&label=MSBuild&color=0078D4) |

## Roadmap

- [ ] Fortify Agentic Analyzer
- [ ] GitHub CodeQL
- [ ] GitLab SAST
