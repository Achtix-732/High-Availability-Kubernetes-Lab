# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Define a default value so it's not empty if the builder fails to provide it
ARG BUILDPLATFORM=linux/amd64

# Stage 1: Build Stage (ใช้ SDK ในการคอมไพล์)
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS build-stage
WORKDIR /app

# แก้ปัญหา gRPC Segfault (Code 139) โดยการใช้ protoc ของระบบ
RUN apt-get update && apt-get install -y protobuf-compiler
ENV PROTOBUF_PROTOC=/usr/bin/protoc
ENV GRPC_PROTOC_PLUGIN_PATH_LINUX_X64=/usr/bin/protoc
ENV GRPC_PROTOC_PLUGIN_PATH_LINUX_ARM64=/usr/bin/protoc

# 1. Copy เฉพาะไฟล์โปรเจกต์มา Restore ก่อน (ช่วยเรื่อง Cache)
COPY cartservice.csproj ./
# ระบุ -r linux-arm64 เพื่อให้รองรับ Worker Node ที่เป็น ARM64
RUN dotnet restore cartservice.csproj -r linux-arm64

# 2. Copy ไฟล์ทั้งหมดที่เหลือ
COPY . .

# 3. Publish แอปออกมาเป็นไฟล์ Binary
RUN dotnet publish cartservice.csproj \
    -c release \
    -o /app/publish \
    --no-restore \
    -r linux-arm64 \
    --self-contained false \
    -p:PublishSingleFile=true

# ---------------------------------------------------------

# Stage 2: Final Stage (ใช้ Runtime ขนาดเล็กเพื่อรันแอป)
# ใช้ runtime แทน runtime-deps เพราะเราไม่ได้ทำ self-contained แบบรวม runtime
FROM mcr.microsoft.com/dotnet/runtime:10.0-noble-chiseled AS final-stage
WORKDIR /app

# ดึงไฟล์ที่คอมไพล์เสร็จแล้วมาจาก build-stage
COPY --from=build-stage /app/publish .

# ตั้งค่า Port และสภาพแวดล้อม
EXPOSE 7070
ENV DOTNET_EnableDiagnostics=0 \
    ASPNETCORE_HTTP_PORTS=7070

# ใช้ User สิทธิ์ต่ำเพื่อความปลอดภัย
USER 1000

# รันแอป (ชื่อไฟล์ต้องตรงกับที่ publish ออกมา)
ENTRYPOINT ["./cartservice"]
