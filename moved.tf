# Moved resources for v2

moved {
    from = google_project.p["net-host"]
    to = module.project["net-host"].google_project.this
}

moved {
    from = google_project.p["common-sec"]
    to = module.project["common-sec"].google_project.this
}

moved {
    from = google_project.p["non-prod-app"]
    to = module.project["non-prod-app"].google_project.this
}

moved {
    from = google_project.p["prod-app"]
    to = module.project["prod-app"].google_project.this
}

moved {
    from = google_project_service.apis["net-host/compute.googleapis.com"]
    to = module.project["net-host"].google_project_service.this["compute.googleapis.com"]
}

moved {
    from = google_project_service.apis["common-sec/logging.googleapis.com"]
    to = module.project["common-sec"].google_project_service.this["logging.googleapis.com"]
}

moved {
    from = google_project_service.apis["common-sec/cloudkms.googleapis.com"]
    to = module.project["common-sec"].google_project_service.this["cloudkms.googleapis.com"]
}

moved {
    from = google_project_service.apis["common-sec/storage.googleapis.com"]
    to = module.project["common-sec"].google_project_service.this["storage.googleapis.com"]
}

moved {
    from = google_project_service.apis["non-prod-app/compute.googleapis.com"]
    to = module.project["non-prod-app"].google_project_service.this["compute.googleapis.com"]
}

moved {
    from = google_project_service.apis["non-prod-app/storage.googleapis.com"]
    to = module.project["non-prod-app"].google_project_service.this["storage.googleapis.com"]
}

moved {
    from = google_project_service.apis["prod-app/compute.googleapis.com"]
    to = module.project["prod-app"].google_project_service.this["compute.googleapis.com"]
}

moved {
    from = google_project_service.apis["prod-app/storage.googleapis.com"]
    to = module.project["prod-app"].google_project_service.this["storage.googleapis.com"]
}