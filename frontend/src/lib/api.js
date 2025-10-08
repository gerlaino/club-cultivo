import axios from "axios"

export const api = axios.create({
  baseURL: "http://localhost:3001",
  withCredentials: true, // cookies (sesión Devise)
  headers: { "Content-Type": "application/json", "Accept": "application/json" }
})

export function signIn(email, password) {
  return api.post("/users/sign_in", { user: { email, password } })
}
export function signOut() { return api.delete("/users/sign_out") }
export function me() { return api.get("/me") }

export function listSalas() { return api.get("/salas") }
export function createSala(payload) { return api.post("/salas", { sala: payload }) }

export function listLotes() { return api.get("/lotes") }
export function createLote(payload) { return api.post("/lotes", { lote: payload }) }
