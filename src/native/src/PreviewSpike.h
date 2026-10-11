#pragma once
#ifdef AIE_PREVIEW_SPIKE
#include "RE/Fallout.h"
#include <fstream>
#include <chrono>
#include <cmath>
#include <sstream>

namespace AIE::PreviewSpike
{
    // Experimental engine-reference route. No inventory mutation or world placement.
    class Probe
    {
        RE::NiPointer<RE::TESObjectREFR> ref_;
        RE::NiPointer<RE::NiAVObject> model_;
        RE::Interface3D::Renderer* renderer_{};
        bool attempted_{};
        unsigned frames_{};
        bool positioned_{};
        unsigned cameraFrames_{};
        unsigned diagnosticFrames_{};
        unsigned placementFrames_{};
        void RefreshTransforms(RE::NiAVObject* object, RE::NiUpdateData& update, unsigned depth = 0)
        {
            if (!object || depth > 32) return;
            // Load3D may mark this tree for selective updates. Changing local
            // translation alone does not guarantee Update() recomputes world data.
            object->UpdateWorldData(&update);
            if (auto* node = object->IsNode()) {
                for (auto& child : node->children) RefreshTransforms(child.get(), update, depth + 1);
            }
            object->UpdateWorldBound();
        }
        void Inspect(RE::NiAVObject* object, unsigned depth, unsigned& count, RE::NiBound& aggregate, bool& usable, bool verbose)
        {
            if (!object || depth > 32 || count >= 512) return;
            ++count;
            auto* geometry = object->IsGeometry();
            if (verbose) {
                std::ostringstream out;
                auto* type = object->GetRTTI();
                out << "Spike04: depth=" << depth << " type=" << (type ? type->GetName() : "unknown")
                    << " name=" << object->name.c_str() << " worldRadius=" << object->worldBound.fRadius
                    << " scale=" << object->world.scale << " culled=" << object->GetAppCulled();
                if (geometry) out << " meshRadius=" << geometry->modelBound.fRadius << " rendererData=" << geometry->rendererData;
                Log(out.str().c_str());
            }
            if (geometry) {
                RE::NiBound candidate = geometry->worldBound;
                if (!std::isfinite(candidate.fRadius) || candidate.fRadius <= 0.01F) {
                    candidate.center = geometry->world * geometry->modelBound.center;
                    candidate.fRadius = std::abs(geometry->world.scale) * geometry->modelBound.fRadius;
                }
                if (std::isfinite(candidate.fRadius) && candidate.fRadius > 0.01F &&
                    std::isfinite(candidate.center.x) && std::isfinite(candidate.center.y) && std::isfinite(candidate.center.z)) {
                    if (!usable) { aggregate = candidate; usable = true; }
                    else {
                        // Conservative sphere around the first mesh, covering all child meshes.
                        const auto delta = candidate.center - aggregate.center;
                        const float distance = std::sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z);
                        aggregate.fRadius = (std::max)(aggregate.fRadius, distance + candidate.fRadius);
                    }
                }
            }
            if (auto* node = object->IsNode()) {
                for (auto& child : node->children) Inspect(child.get(), depth + 1, count, aggregate, usable, verbose);
            }
        }
        void Log(const char* text)
        {
            std::ofstream out("Data/F4SE/Plugins/AIE_PreviewSpike.log", std::ios::app);
            out << text << '\n';
        }
    public:
        void PositionAtCameraCenter()
        {
            if (!renderer_ || !model_ || positioned_) return;
            if (++placementFrames_ < 30) return; // let renderer camera/parent settle
            if (placementFrames_ > 240) { Log("Spike06: placement timeout"); positioned_ = true; return; }
            auto* camera = renderer_->nativeAspect.get();
            if (!camera) {
                if (++cameraFrames_ == 60) Log("Spike03: nativeAspect camera absent after 60 frames");
                return;
            }
            RE::NiUpdateData update;
            update.camera = camera;
            RefreshTransforms(model_.get(), update);
            auto bound = model_->worldBound;
            const bool verbose = diagnosticFrames_ == 0 || diagnosticFrames_ == 60 || diagnosticFrames_ == 180;
            if (diagnosticFrames_ < 181) {
                unsigned count = 0;
                RE::NiBound meshBound{};
                bool usable = false;
                Inspect(model_.get(), 0, count, meshBound, usable, verbose);
                if (verbose) {
                    std::ostringstream out;
                    out << "Spike04: frame=" << diagnosticFrames_ << " objects=" << count << " usableMeshBounds=" << usable;
                    Log(out.str().c_str());
                }
                if ((!std::isfinite(bound.fRadius) || bound.fRadius <= 0.01F) && usable) {
                    bound = meshBound;
                    model_->worldBound = bound;
                    Log("Spike04: using child geometry bounds for center positioning");
                }
                ++diagnosticFrames_;
            }
            if (!std::isfinite(bound.fRadius) || bound.fRadius <= 0.01F) {
                if (++cameraFrames_ == 60) Log("Spike03: model has no usable world bound");
                return;
            }
            const RE::NiPoint3 origin = camera->world.translate;
            const float distance = (std::max)(bound.fRadius * 5.0F, camera->viewFrustum.near + bound.fRadius * 2.0F);
            RE::NiPoint3 target;
            bool found = false;
            float bestError = 1000000.0F;
            // Test camera-local basis directions against the actual projection
            // and frustum, rather than relying on the suspect AE ray wrapper.
            for (unsigned axis = 0; axis < 3; ++axis) {
                for (float sign : { -1.0F, 1.0F }) {
                    RE::NiPoint3 offset(0.0F, 0.0F, 0.0F);
                    offset[axis] = sign * distance;
                    const auto candidate = camera->world * offset;
                    float sx{}, sy{}, sz{};
                    const bool projected = camera->WorldPtToScreenPt3(candidate, sx, sy, sz, 0.0001F);
                    const bool visible = camera->PointInFrustum(candidate, bound.fRadius);
                    if (placementFrames_ == 30) {
                        std::ostringstream out;
                        out << "Spike07: basis=" << axis << " sign=" << sign << " projected=" << projected
                            << " screen=" << sx << ',' << sy << ',' << sz << " inFrustum=" << visible
                            << " cameraScale=" << camera->world.scale;
                        Log(out.str().c_str());
                    }
                    const float error = (sx - 0.5F) * (sx - 0.5F) + (sy - 0.5F) * (sy - 0.5F);
                    if (projected && visible && std::isfinite(error) && error < bestError) {
                        target = candidate; bestError = error; found = true;
                    }
                }
            }
            if (!found || bestError > 0.01F) {
                if (placementFrames_ % 30 == 0) Log("Spike07: no verified camera-center candidate; not moving model");
                return;
            }
            // Convert validated world displacement through the parent transform.
            const auto displacement = target - bound.center;
            if (model_->parent) {
                const auto& transform = model_->parent->world;
                if (std::abs(transform.scale) < 0.001F) return;
                RE::NiPoint3 localDelta;
                for (unsigned axis = 0; axis < 3; ++axis) {
                    localDelta[axis] = (transform.rotate.entry[0][axis] * displacement.x +
                        transform.rotate.entry[1][axis] * displacement.y +
                        transform.rotate.entry[2][axis] * displacement.z) / transform.scale;
                }
                model_->local.translate += localDelta;
            } else {
                model_->local.translate += displacement;
            }
            RefreshTransforms(model_.get(), update);
            float x{}, y{}, z{};
            const bool projected = camera->WorldPtToScreenPt3(model_->worldBound.center, x, y, z, 0.0001F);
            std::ostringstream message;
            message << "Spike07: frame=" << placementFrames_ << " radius=" << bound.fRadius << " distance=" << distance
                << " projected=" << projected << " screen=" << x << ',' << y << ',' << z
                << " inFrustum=" << camera->NodeInFrustum(model_.get())
                << " target=" << target.x << ',' << target.y << ',' << target.z
                << " actual=" << model_->worldBound.center.x << ',' << model_->worldBound.center.y << ',' << model_->worldBound.center.z;
            if (placementFrames_ == 30 || placementFrames_ % 30 == 0) Log(message.str().c_str());
            renderer_->MainScreen_ClearLights();
            renderer_->MainScreen_AddPointLight(origin, RE::NiColor(1.0F, 1.0F, 1.0F), distance * 4.0F, 1.0F);
            if (projected && std::abs(x - 0.5F) < 0.05F && std::abs(y - 0.5F) < 0.05F && camera->NodeInFrustum(model_.get())) {
                Log("Spike06: model center verified inside camera frustum; visual confirmation still required");
                positioned_ = true;
            }
        }
        ~Probe() { Clear(); }
        void Clear()
        {
            if (renderer_) {
                renderer_->Disable();
                renderer_->MainScreen_SetScreenAttached3D(nullptr);
                renderer_->MainScreen_SetWorldAttached3D(nullptr);
                renderer_->MainScreen_ClearLights();
                renderer_->Release();
                renderer_ = nullptr;
            }
            model_.reset();
            if (ref_) {
                ref_->Set3D(nullptr, false);
                ref_->SetWantsDelete(true);
                ref_.reset();
                Log("temporary reference released");
            }
            attempted_ = false;
            frames_ = 0;
            positioned_ = false;
            cameraFrames_ = 0;
            diagnosticFrames_ = 0;
            placementFrames_ = 0;
        }
        void Tick(Scaleform::GFx::Movie* movie, bool extraction)
        {
            if (!extraction) { if (attempted_) Clear(); return; }
            if (!movie) return;
            if (!attempted_) {
                attempted_ = true;
                Log("PreviewSpike07: begin AE camera-basis validated placement");
                auto* data = RE::TESDataHandler::GetSingleton();
                // Temporary PoC control: use a different vanilla weapon to isolate
                // the empty receiver-only result. Do not infer any mesh filename.
                auto* form = data ? data->LookupForm(0x0008C14D, "Fallout4.esm") : nullptr;
                auto* weapon = form ? form->As<RE::TESObjectWEAP>() : nullptr;
                if (!weapon) { Log("weapon lookup failed"); return; }
                {
                    std::ostringstream out;
                    out << "Spike05: form=" << std::hex << weapon->GetFormID()
                        << " model=" << weapon->GetModel()
                        << " hasTemplate=" << (weapon->weaponTemplate != nullptr)
                        << " hasEmbeddedMod=" << (weapon->embeddedWeaponMod != nullptr);
                    Log(out.str().c_str());
                }
                auto factories = RE::IFormFactory::GetFormFactories();
                auto* factory = factories[std::to_underlying(RE::ENUM_FORM_ID::kREFR)];
                auto* created = factory ? factory->DoCreate() : nullptr;
                auto* reference = created ? created->As<RE::TESObjectREFR>() : nullptr;
                if (!reference) { Log("reference creation failed"); return; }
                ref_ = reference;
                ref_->SetObjectReference(weapon);
                Log("temporary reference created; requesting engine background Load3D");
                model_ = ref_->Load3D(true);
            }
            if (!ref_) return;
            if (renderer_) { PositionAtCameraCenter(); return; }
            if (!model_) model_ = ref_->Get3D();
            if (!model_) {
                if (++frames_ == 300) { Log("no model after 300 menu frames; stopping probe"); Clear(); attempted_ = true; }
                return;
            }
            Log("NiAVObject obtained; creating Interface3D renderer");
            renderer_ = RE::Interface3D::Renderer::Create(RE::BSFixedString("AIEPreviewSpike"), RE::UI_DEPTH_PRIORITY::kStandard3DModel, 45.0F, true);
            if (!renderer_) { Log("renderer creation failed"); return; }
            renderer_->MainScreen_SetBackgroundMode(RE::Interface3D::BackgroundMode::kLive);
            renderer_->Offscreen_SetPostEffect(RE::Interface3D::PostEffect::kNone);
            renderer_->MainScreen_SetWorldAttached3D(model_.get());
            // SetViewport also changes the supplied Scaleform movie. Never pass
            // the extractor movie here: Spike01 shrank the whole UI on AE.
            Log("root attached; extractor Movie viewport left untouched");
            renderer_->MainScreen_AddPointLight(RE::NiPoint3(0.0F, -100.0F, 100.0F), RE::NiColor(1.0F, 1.0F, 1.0F), 500.0F, 1.0F);
            renderer_->Enable();
            PositionAtCameraCenter();
            Log("renderer enabled; visual confirmation required");
        }
    };
}
#endif
