resource "terraform_data" "test" {
  input = "bar"
}

module "baz" {
  source = "../baz"
}
