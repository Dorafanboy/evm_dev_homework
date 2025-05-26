# PancakeSwap Trader

Смарт-контракт для автоматической торговли на PancakeSwap.

## Что делает

**Задание 1:** Покупает токены через `swapETHForExactTokens`  
**Задание 2:** Добавляет купленные токены и BNB в ликвидность

## Для деплоя

### 0. Клонирование репозитория
```bash
git clone https://github.com/Dorafanboy/evm_dev_homework.git
```

### 1. Установка
```bash
npm install
```

### 2. Настройка
В файле`.env` указать приватный ключ:
```
PRIVATE_KEY=private_key_without_0x_prefix
```

### 3. Компиляция
```bash
npm run compile
```

### 4. Деплой
```bash
# Testnet
npm run deploy:testnet

# Mainnet
npm run deploy:mainnet
```

## Функции

- `buyTokensExact()` - покупка точного количества токенов
- `buyTokensExactDirect()` - альтернативная реализация через Factory/Pair
- `swapAndAddLiquidity()` - покупка + добавление в ликвидность
- `addLiquidityWithTokens()` - добавление ликвидности с готовыми токенами

## Адреса

**BSC Mainnet Router:** `0x10ED43C718714eb63d5aA57B78B54704E256024E`  
**BSC Testnet Router:** `0xD99D1c33F9fC3444f8101754aBC46c52416550D1`
