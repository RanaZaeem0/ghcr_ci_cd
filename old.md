name: Deploy to EC2 with GHCR Cache

on:
push:
branches: [main]

jobs:
build-and-deploy:
runs-on: ubuntu-latest
timeout-minutes: 15

    steps:
      # 1️⃣ Checkout the repository
      - name: Checkout repository
        uses: actions/checkout@v4

      # 2️⃣ Login to GitHub Container Registry
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GH_PAT }}

      # 3️⃣ Pull last cached image (if exists)
      - name: Pull cached image from GHCR
        run: |
          export DOCKER_BUILDKIT=1
          docker pull ghcr.io/saylanitechpk/saylani_bot:latest || true

      # 4️⃣ Build Docker image using GHCR cache
      - name: Build Docker image (cached)
        run: |
          export DOCKER_BUILDKIT=1
          docker build \
            --target production \
            --cache-from ghcr.io/saylanitechpk/saylani_bot:latest \
            --tag ghcr.io/saylanitechpk/saylani_bot:latest \
            .

      # 5️⃣ Push the image back to GHCR (so next build is cached)
      - name: Push image to GHCR
        run: |
          docker push ghcr.io/saylanitechpk/saylani_bot:latest

      # 6️⃣ Setup SSH for EC2 connection
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.EC2_SSH_KEY }}

      # 6.5️⃣ Test SSH connection
      - name: Test SSH connection
        run: |
          echo "🔍 Testing SSH connection..."
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${{ secrets.EC2_HOST }} "echo '✅ SSH connection successful'"

      # 7️⃣ Deploy on EC2 (pull and restart container)
      - name: Deploy on EC2
        run: |
          ssh -o StrictHostKeyChecking=no ubuntu@${{ secrets.EC2_HOST }} << 'EOF'
            set -e
            cd ~

            # Function to check disk space
            check_disk_space() {
              AVAILABLE=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
              echo "Available disk space: ${AVAILABLE}GB"
              if (( $(echo "$AVAILABLE < 2" | bc -l) )); then
                echo "❌ Warning: Low disk space (< 2GB available)"
                echo "Attempting cleanup..."
                sudo docker system prune -af --volumes || true
                sudo journalctl --vacuum-size=100M || true
              fi
            }

            echo "===> Checking disk space..."
            check_disk_space

            echo "===> Cleaning old Docker resources..."
            sudo docker system prune -af || true

            echo "===> Logging into GHCR..."
            echo "${{ secrets.GH_PAT }}" | sudo docker login ghcr.io -u ${{ github.actor }} --password-stdin

            echo "===> Pulling latest cached image..."
            sudo docker pull ghcr.io/saylanitechpk/saylani_bot:latest

            echo "===> Stopping old container..."
            sudo docker stop saylani_bot || true
            sudo docker rm saylani_bot || true

            echo "===> Updating environment file..."
            mkdir -p /home/ubuntu/smit-bot
            echo "${{ secrets.BACKEND_ENV }}" > /home/ubuntu/smit-bot/.env

            echo "===> Running new container..."
            sudo docker run -d \
              --name saylani_bot \
              -p 8000:8000 \
              --env-file /home/ubuntu/smit-bot/.env \
              --restart unless-stopped \
              ghcr.io/saylanitechpk/saylani_bot:latest

            # Wait for service to be ready
            echo "===> Waiting for service to start..."
            sleep 10

            # Health check
            for i in {1..30}; do
              if curl -f http://localhost:8000/health >/dev/null 2>&1; then
                echo "✅ Service is healthy!"
                break
              fi
              if [ $i -eq 30 ]; then
                echo "❌ Service health check failed"
                sudo docker logs saylani_bot
                exit 1
              fi
              echo "Waiting for service... ($i/30)"
              sleep 2
            done

            # Final cleanup
            sudo docker image prune -f || true
            check_disk_space

            echo "✅ Deployment completed successfully on EC2!"
          EOF
