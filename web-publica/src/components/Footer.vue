<template>
  <footer class="bg-dark text-light py-5 mt-5">
    <div class="container">
      <div class="row">
        <div class="col-md-4 mb-4">
          <h5 class="text-success">{{ club?.name }}</h5>
          <p class="small text-muted">{{ club?.legal_name }}</p>
          <p class="small">
            Cannabis medicinal de calidad para nuestros socios.
          </p>
        </div>

        <div class="col-md-4 mb-4">
          <h5 class="text-success">Contacto</h5>
          <ul class="list-unstyled small">
            <li v-if="club?.address" class="mb-2">
              <i class="bi bi-geo-alt-fill text-success me-2"></i>
              {{ club.address }}, {{ club.city }}
            </li>
            <li v-if="club?.phone" class="mb-2">
              <i class="bi bi-telephone-fill text-success me-2"></i>
              {{ club.phone }}
            </li>
            <li v-if="club?.email" class="mb-2">
              <i class="bi bi-envelope-fill text-success me-2"></i>
              {{ club.email }}
            </li>
          </ul>
        </div>

        <div class="col-md-4 mb-4">
          <h5 class="text-success">Seguinos</h5>
          <div class="d-flex gap-3">
            <a href="#" class="text-light fs-4"><i class="bi bi-facebook"></i></a>
            <a href="#" class="text-light fs-4"><i class="bi bi-instagram"></i></a>
            <a href="#" class="text-light fs-4"><i class="bi bi-twitter"></i></a>
          </div>
        </div>
      </div>

      <hr class="border-secondary">

      <div class="row">
        <div class="col-md-12 text-center small text-muted">
          <p class="mb-0">
            © {{ new Date().getFullYear() }} {{ club?.name }}. Todos los derechos reservados.
          </p>
        </div>
      </div>
    </div>
  </footer>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import publicApi from '@/api/publicApi'

const club = ref(null)

onMounted(async () => {
  try {
    club.value = await publicApi.getClub()
  } catch (error) {
    console.error('Error cargando info del club:', error)
  }
})
</script>