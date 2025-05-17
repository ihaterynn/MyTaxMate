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

# Make port 8000 available (as per your chatbot_server.py)
EXPOSE 8000

# Define environment variable for the API key (will be set at runtime)
ENV DASHSCOPE_API_KEY="'sk-81b1061db3e74c43875ceaa385693af6'"
# It's better to pass this at runtime via -e or docker-compose

# Run chatbot_server.py when the container launches
# Assuming your FastAPI app instance is named 'app' in chatbot_server.py
CMD ["uvicorn", "chatbot_server:app", "--host", "0.0.0.0", "--port", "8000"]