# Start from a Perl base image
FROM perl:5.30

# Update system and install system dependencies for DBD::Pg
RUN apt-get update && apt-get install -y libdbd-pg-perl && \
    rm -rf /var/lib/apt/lists/*

# Create a directory to hold your application
WORKDIR /app

# Copy the cpanfile and install the necessary Perl modules
COPY cpanfile .
RUN cpanm App::cpanminus && cpanm --installdeps .

# Copy the rest of your application's files into the image
COPY . .

# Overwrite the flow_conf.yaml with the updated one
COPY docker.flow_conf.yaml flow_conf.yaml

# Expose the port your app will run on
EXPOSE 5000

# Run your application
CMD ["plackup", "flow.psgi"]
