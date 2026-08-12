FROM python:3.11-slim
WORKDIR /app
COPY app/lambda/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/lambda/handler.py .
USER 65532:65532
CMD ["python", "-c", "print('Security demo image')"]
