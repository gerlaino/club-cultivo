// frontend/src/lib/api.js
import axios from "axios";
const API_URL =
  import.meta.env.VITE_API_URL || "http://localhost:3001";

export const api = axios.create({
  baseURL: API_URL,
  withCredentials: true,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// --- Auth ---
export function signIn(email, password) {
  return api.post("/users/sign_in", { user: { email, password } });
}
export function signOut() {
  return api.delete("/users/sign_out");
}
export function me() {
  return api.get("/me");
}

// --- Salas ---
export function listSalas() {
  return api.get("/salas");
}
export function getSala(id) {
  return api.get(`/salas/${id}`);
}
export function createSala(payload) {
  return api.post("/salas", { sala: payload });
}
export function updateSala(id, payload) {
  return api.put(`/salas/${id}`, { sala: payload });
}
export function deleteSala(id) {
  return api.delete(`/salas/${id}`);
}

// --- Lotes (si los usás) ---
export function listLotes() {
  return api.get("/lotes");
}
export function createLote(payload) {
  return api.post("/lotes", { lote: payload });
}
