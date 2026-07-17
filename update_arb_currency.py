import json

def update_arb(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in new_keys.items():
        data[k] = v
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

keys_pt = {
    "notifTransactionReceivedTitle": "Transferência Recebida",
    "notifTransactionReceivedBody": "Você recebeu {amount} {moeda} via {rede} na carteira {carteira}.",
    "@notifTransactionReceivedBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "carteira": {"type": "String"} } },

    "notifTransactionSentTitle": "Transferência enviada com sucesso",
    "notifTransactionSentBody": "Você enviou via {rede} {amount} {moeda} para {endereco}.",
    "@notifTransactionSentBody": { "placeholders": { "rede": {"type": "String"}, "amount": {"type": "String"}, "moeda": {"type": "String"}, "endereco": {"type": "String"} } },

    "notifTransactionInvoiceStatusTitle": "Pagamento de invoice está {status}",
    "@notifTransactionInvoiceStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionInvoiceStatusBody": "Invoice de {amount} {moeda} está {status}.",
    "@notifTransactionInvoiceStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "status": {"type": "String"} } },
    
    "notifTransactionStatusTitle": "Depósito {status}",
    "@notifTransactionStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionStatusBody": "Transferência de {amount} {moeda} via {rede} está {status}.",
    "@notifTransactionStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "status": {"type": "String"} } }
}

keys_en = {
    "notifTransactionReceivedTitle": "Transfer Received",
    "notifTransactionReceivedBody": "You received {amount} {moeda} via {rede} in wallet {carteira}.",
    "@notifTransactionReceivedBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "carteira": {"type": "String"} } },

    "notifTransactionSentTitle": "Transfer successfully sent",
    "notifTransactionSentBody": "You sent {amount} {moeda} via {rede} to {endereco}.",
    "@notifTransactionSentBody": { "placeholders": { "rede": {"type": "String"}, "amount": {"type": "String"}, "moeda": {"type": "String"}, "endereco": {"type": "String"} } },

    "notifTransactionInvoiceStatusTitle": "Invoice payment is {status}",
    "@notifTransactionInvoiceStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionInvoiceStatusBody": "Invoice of {amount} {moeda} is {status}.",
    "@notifTransactionInvoiceStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "status": {"type": "String"} } },
    
    "notifTransactionStatusTitle": "Deposit {status}",
    "@notifTransactionStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionStatusBody": "Transfer of {amount} {moeda} via {rede} is {status}.",
    "@notifTransactionStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "status": {"type": "String"} } }
}

keys_es = {
    "notifTransactionReceivedTitle": "Transferencia Recibida",
    "notifTransactionReceivedBody": "Ha recibido {amount} {moeda} a través de {rede} en la billetera {carteira}.",
    "@notifTransactionReceivedBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "carteira": {"type": "String"} } },

    "notifTransactionSentTitle": "Transferencia enviada con éxito",
    "notifTransactionSentBody": "Usted envió {amount} {moeda} a través de {rede} para {endereco}.",
    "@notifTransactionSentBody": { "placeholders": { "rede": {"type": "String"}, "amount": {"type": "String"}, "moeda": {"type": "String"}, "endereco": {"type": "String"} } },

    "notifTransactionInvoiceStatusTitle": "El pago de la factura está {status}",
    "@notifTransactionInvoiceStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionInvoiceStatusBody": "La factura de {amount} {moeda} está {status}.",
    "@notifTransactionInvoiceStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "status": {"type": "String"} } },
    
    "notifTransactionStatusTitle": "Depósito {status}",
    "@notifTransactionStatusTitle": { "placeholders": { "status": {"type": "String"} } },
    "notifTransactionStatusBody": "Transferencia de {amount} {moeda} a través de {rede} está {status}.",
    "@notifTransactionStatusBody": { "placeholders": { "amount": {"type": "String"}, "moeda": {"type": "String"}, "rede": {"type": "String"}, "status": {"type": "String"} } }
}

update_arb('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_pt.arb', keys_pt)
update_arb('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_en.arb', keys_en)
update_arb('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_es.arb', keys_es)
