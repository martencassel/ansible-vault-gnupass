default:
	docker build -t vault-gnupass:latest .
	docker run -it --rm --name vault-gnupass vault-gnupass:latest
