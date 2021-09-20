FROM julia:latest

ADD Project.toml /Project.toml
ADD Manifest.toml /Manifest.toml
COPY src/ /src/

ENV JULIA_PROJECT "."
RUN julia -e "using Pkg; pkg\"activate . \"; pkg\"instantiate\"; pkg\"precompile\"; "
ENV JULIA_DEPOT_PATH "/home/julia/.julia"
