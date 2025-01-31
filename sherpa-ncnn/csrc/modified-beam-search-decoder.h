/**
 * Copyright (c)  2022  Xiaomi Corporation (authors: Fangjun Kuang)
 * Copyright (c)  2022                     (Pingfeng Luo)
 *
 * See LICENSE for clarification regarding multiple authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef SHERPA_NCNN_CSRC_MODIFIED_BEAM_SEARCH_DECODER_H_
#define SHERPA_NCNN_CSRC_MODIFIED_BEAM_SEARCH_DECODER_H_

#include <memory>
#include <vector>

#include "sherpa-ncnn/csrc/features.h"
#include "sherpa-ncnn/csrc/recognizer.h"

namespace sherpa_ncnn {

class ModifiedBeamSearchDecoder : public Decoder {
 public:
  ModifiedBeamSearchDecoder(const DecoderConfig &config, Model *model,
                            const knf::FbankOptions &fbank_opts,
                            const sherpa_ncnn::SymbolTable *sym,
                            const Endpoint *endpoint)
      : config_(config),
        model_(model),
        feature_extractor_(fbank_opts),
        sym_(sym),
        blank_id_(model_->BlankId()),
        context_size_(model_->ContextSize()),
        segment_(model->Segment()),
        offset_(model_->Offset()),
        num_processed_(0),
        endpoint_start_frame_(0),
        endpoint_(endpoint) {
    ResetResult();
  }

  void AcceptWaveform(float sample_rate, const float *input_buffer,
                      int32_t frames_per_buffer) override;

  void Decode() override;

  RecognitionResult GetResult() override;

  void ResetResult() override;

  bool IsEndpoint() override;

  void Reset() override;

  void InputFinished() override;

 private:
  ncnn::Mat BuildDecoderInput(const std::vector<Hypothesis> &hyps) const;

  const DecoderConfig config_;
  Model *model_;
  sherpa_ncnn::FeatureExtractor feature_extractor_;
  const sherpa_ncnn::SymbolTable *sym_;
  const int32_t blank_id_;
  const int32_t context_size_;
  const int32_t segment_;
  const int32_t offset_;
  std::vector<ncnn::Mat> encoder_state_;
  int32_t num_processed_;
  int32_t endpoint_start_frame_;
  const Endpoint *endpoint_;
  RecognitionResult result_;
};

}  // namespace sherpa_ncnn

#endif  // SHERPA_NCNN_CSRC_MODIFIED_BEAM_SEARCH_DECODER_H_
