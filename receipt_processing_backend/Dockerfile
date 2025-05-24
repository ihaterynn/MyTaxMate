# Use an official Python runtime as a parent image
FROM python:3.10

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . .

# Make port 8002 available to the world outside this container
# This is the port uvicorn is configured to run on in your main.py
EXPOSE 8002

# Define environment variable for the API key (will be set at runtime)
ENV DASHSCOPE_API_KEY="your_api_key_here" 
# It's better to pass this at runtime via -e or docker-compose

# Run main.py when the container launches
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002"]