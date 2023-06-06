# Start from a Perl base image
FROM perl:5.30

# Install cpanminus
RUN cpanm App::cpanminus

# Create a directory to hold your application
WORKDIR /

# Copy your application's files into the image
COPY . .

# Install the necessary Perl modules
RUN cpanm -n --installdeps .

# Expose the port your app will run on
EXPOSE 5000

# Run your application
CMD ["plackup", "flow.psgi"]
