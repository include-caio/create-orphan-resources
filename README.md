## Criar recursos órfãos

O objetivo desse Terraform é criar recursos órfãos para validar o [Workbook de recursos órfãos](https://github.com/dolevshor/azure-orphan-resources) e o [script de remoção de recursos órfãos](https://github.com/include-caio/delete-orphan-resources)

<img src="https://i.imgur.com/srkBOrO.png" width="650">

A variável "subscription_id" foi definida como variável de ambiente com o comando:

```export TF_VAR_subscription_id="00000000-0000-0000-0000-000000000000"```