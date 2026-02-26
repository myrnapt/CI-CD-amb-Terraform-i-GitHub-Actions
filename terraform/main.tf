# ---------- DATA ----------
# Gets the list of available azs in the defined region.
data "aws_availability_zones" "available_zones" {
  state = "available"
}

# git add .
# git commit -m "Fix formatting"
# git push


#Esto es una prueba