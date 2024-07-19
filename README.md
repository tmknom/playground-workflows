# playground-workflows

Debugging on GitHub Actions.

<!-- actdocs start -->

## Description

This action discovers the Terraform state directories that use the specified local modules.
A "state directory" is where you run `terraform plan` or `terraform apply`.
It usually contains the `terraform.tfstate` file.

For example, if you modify a Terraform local module, you can see which state directories are affected.
With this action, you can easily identify relationships in your Terraform configurations,
making it easier to manage changes and understand their impacts.

## Usage

```yaml
  steps:
    - name: Tf dependency
      uses: tmknom/tf-dependency-action@v0
      with:
        modules: module/foo,module/bar
```

## Inputs

| Name | Description | Default | Required |
| :--- | :---------- | :------ | :------: |
| base-dir | The base directory that contains the state directories and Terraform modules. | `${{ github.workspace }}` | no |
| modules | Terraform module directories. | n/a | no |

## Outputs

| Name | Description |
| :--- | :---------- |
| dirs | The state directories that use the specified modules. |

<!-- actdocs end -->

## Release notes

See [GitHub Releases][releases].

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.

[releases]: https://github.com/tmknom/playground-workflows/releases
