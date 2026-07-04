require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
const abi = require('./contractABI.json');

const app = express();
app.use(cors());
app.use(express.json());

// Inisialisasi Ethers Provider & Contract (Read-Only)
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const contract = new ethers.Contract(process.env.CONTRACT_ADDRESS, abi, provider);

app.get('/health', (req, res) => res.json({ status: 'ok', chain: 'connected' }));

// Endpoint utama buat narik full history produk dari blockchain
app.get('/product/:id', async (req, res) => {
  try {
    const result = await contract.getProductFullHistory(req.params.id);
    
    // Log ke terminal API buat kita intip isi asli object-nya di console nodemon
    console.log("Data mentah dari blockchain:", result);

    res.json({
      product: {
        id: result[0]?.id ? result[0].id.toString() : req.params.id,
        producer: result[0]?.producer || "0x0",
        batchNumber: result[0]?.batchNumber || "",
        status: result[0]?.status !== undefined ? Number(result[0].status) : 0,
      },
      certificate: {
        issuer: result[1]?.issuer || "0x0",
        ipfsHash: result[1]?.ipfsHash || "",
        expiresAt: result[1]?.expiresAt ? result[1].expiresAt.toString() : "0",
      },
      custodyChain: Array.isArray(result[2]) ? result[2].map(holder => ({
        handler: holder?.handler || "0x0",
        timestamp: holder?.timestamp ? holder.timestamp.toString() : "0",
        location: holder?.location || "",
        verified: holder?.verified || false
      })) : [],
      certificateValid: result[3] || false,
    });
  } catch (err) {
    res.status(500).json({ error: 'Terjadi kesalahan saat membaca data contract', details: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 API Layer running on port ${PORT}`);
});
