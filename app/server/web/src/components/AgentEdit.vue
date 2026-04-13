<template>
  <div class="h-full flex flex-col bg-gradient-to-b from-background to-muted/20 border shadow-sm overflow-hidden">
    <!-- Header with Agent Name -->
    <div class="px-4 py-2.5 border-b bg-background/95 backdrop-blur flex items-center justify-between shrink-0">
      <div class="flex items-center gap-2">
        <Button
          variant="ghost"
          size="icon"
          @click="handleReturn"
          class="text-muted-foreground hover:text-foreground h-7 w-7"
        >
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <div class="flex items-center gap-2">
          <h1 class="text-sm font-medium">{{ isEditMode ? t('agent.editTitle') : t('agent.createTitle') }}</h1>
          <span class="text-xs text-muted-foreground/60">{{ store.formData.name || t('agent.unnamed') }}</span>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          @click="handleSave(false)"
          :disabled="saving || !store.isStep1Valid"
          class="h-7 text-xs px-3"
        >
          <Loader v-if="saving" class="mr-1.5 h-3 w-3 animate-spin" />
          <Save v-else class="mr-1.5 h-3 w-3" />
          {{ t('common.save') }}
        </Button>
        <Button
          @click="handleSave(true)"
          :disabled="saving || !store.isStep1Valid"
          size="sm"
          class="bg-primary hover:bg-primary/90 h-7 text-xs px-3"
        >
          <Loader v-if="saving" class="mr-1.5 h-3 w-3 animate-spin" />
          <Check v-else class="mr-1.5 h-3 w-3" />
          {{ t('common.saveAndExit') }}
        </Button>
      </div>
    </div>

    <!-- Main Content: Left Sidebar + Right Content -->
    <div class="flex-1 flex min-h-0">
      <!-- Left Sidebar - Navigation -->
      <div class="w-48 border-r bg-muted/20 flex flex-col shrink-0 overflow-y-auto">
        <nav class="py-3 px-2 space-y-0.5">
          <button
            v-for="section in sections"
            :key="section.id"
            @click="scrollToSection(section.id)"
            class="w-full flex items-center gap-2.5 px-3 py-2 rounded-md text-xs transition-all duration-200"
            :class="activeSection === section.id ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground/70 hover:bg-muted/60 hover:text-foreground'"
          >
            <component :is="section.icon" class="h-3.5 w-3.5 shrink-0" />
            <span class="truncate">{{ section.label }}</span>
          </button>
        </nav>
      </div>

      <!-- Right Content - Scrollable -->
      <div ref="contentRef" class="flex-1 overflow-y-auto scroll-smooth min-h-0 bg-background">
        <div class="max-w-3xl mx-auto py-8 px-8 space-y-10">
          <!-- Basic Info Section -->
          <section id="basic" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <User class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.basicInfo') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.basicInfoTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-2">
                <p class="text-xs text-muted-foreground">{{ t('agentEdit.basicInfoDesc') }}</p>
              </div>
            </div>
            <div class="space-y-5 pl-10">
              <FormItem :label="t('agent.name')" :error="store.errors.name" required>
                <Input
                  v-model="store.formData.name"
                  :placeholder="t('agent.namePlaceholder')"
                  :disabled="store.formData.id === 'default'"
                  class="h-10"
                />
              </FormItem>

              <FormItem :label="t('agent.description')" :error="store.errors.description">
                <Textarea
                  v-model="store.formData.description"
                  :rows="3"
                  :placeholder="t('agent.descriptionPlaceholder')"
                  class="resize-none"
                />
              </FormItem>

              <FormItem :error="store.errors.systemPrefix">
                <div class="flex justify-between items-center mb-2">
                  <Label :class="store.errors.systemPrefix ? 'text-destructive' : ''">{{ t('agent.systemPrefix') }}</Label>
                  <Button
                    size="sm"
                    variant="ghost"
                    class="flex items-center gap-1 text-foreground hover:bg-transparent h-7"
                    @click="showOptimizeModal = true"
                    :disabled="isOptimizing"
                  >
                    <Sparkles class="h-3.5 w-3.5 text-yellow-400" />
                    <span class="text-xs">{{ t('agentEdit.aiOptimize') }}</span>
                  </Button>
                </div>
                <Textarea
                  v-model="store.formData.systemPrefix"
                  :rows="10"
                  :placeholder="t('agent.systemPrefixPlaceholder')"
                  class="font-mono text-sm"
                />
              </FormItem>
            </div>
          </section>

          <!-- Strategy Section -->
          <section id="strategy" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Cpu class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.strategy') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.strategyTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
            </div>
            <div class="space-y-6 pl-10">
              <!-- Row 1: Memory Type & Agent Mode -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <FormItem :label="t('agent.memoryType')">
                  <Select v-model="store.formData.memoryType">
                    <SelectTrigger class="h-10">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="session">{{ t('agent.sessionMemory') }}</SelectItem>
                      <SelectItem value="user">{{ t('agent.userMemory') }}</SelectItem>
                    </SelectContent>
                  </Select>
                </FormItem>

                <FormItem :label="t('agent.agentMode')">
                  <Select v-model="store.formData.agentMode">
                    <SelectTrigger class="h-10">
                      <SelectValue :placeholder="t('agent.modeAuto')" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="fibre">{{ t('agent.modeFibre') }}</SelectItem>
                      <SelectItem value="simple">{{ t('agent.modeSimple') }}</SelectItem>
                    </SelectContent>
                  </Select>
                </FormItem>
              </div>

              <!-- Row 2: Deep Thinking, More Suggest, Max Loop -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <FormItem :label="t('agent.deepThinking')">
                  <Tabs :model-value="getSelectValue(store.formData.deepThinking)" @update:model-value="(v) => setSelectValue('deepThinking', v)">
                    <TabsList class="grid w-full grid-cols-3 h-10">
                      <TabsTrigger value="auto">{{ t('agent.auto') }}</TabsTrigger>
                      <TabsTrigger value="enabled">{{ t('agent.enabled') }}</TabsTrigger>
                      <TabsTrigger value="disabled">{{ t('agent.disabled') }}</TabsTrigger>
                    </TabsList>
                  </Tabs>
                </FormItem>

                <FormItem :label="t('agent.moreSuggest')">
                  <div class="flex items-center h-10 gap-3 border rounded-md px-3 bg-background">
                    <Switch :checked="store.formData.moreSuggest" @update:checked="(v) => store.formData.moreSuggest = v" />
                    <span class="text-sm text-muted-foreground">{{ store.formData.moreSuggest ? t('agent.enabled') : t('agent.disabled') }}</span>
                  </div>
                </FormItem>

                <FormItem :label="t('agent.maxLoopCount')">
                  <Input type="number" v-model.number="store.formData.maxLoopCount" min="1" max="200" class="h-10" />
                </FormItem>
              </div>

            </div>
          </section>

          <!-- Model Provider Section -->
          <section id="model" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Server class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.modelProvider') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.modelTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
            </div>
            <div class="pl-10 space-y-6">
              <FormItem :label="t('agent.modelProvider')">
                <Select v-model="llmProviderSelectValue">
                  <SelectTrigger class="h-10">
                    <SelectValue :placeholder="t('agent.selectModelProvider')" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="provider in providers" :key="provider.id" :value="provider.id">
                      <div class="flex items-center gap-2">
                        <span>{{ provider.name }} ({{ provider.model }})</span>
                        <div class="flex items-center gap-1 ml-2">
                          <span class="inline-flex items-center justify-center w-4 h-4 text-[10px] font-medium bg-primary/10 text-primary rounded">T</span>
                          <ImageIcon v-if="provider.supports_multimodal" class="w-4 h-4 text-primary" />
                        </div>
                      </div>
                    </SelectItem>
                  </SelectContent>
                </Select>
              </FormItem>

              <!-- 快速模型选择（可选） -->
              <FormItem :label="t('agent.fastModelProvider')">
                <Select v-model="fastLlmProviderSelectValue">
                  <SelectTrigger class="h-10">
                    <SelectValue :placeholder="t('agent.selectFastModelProvider')" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem :value="defaultProviderOption">
                      <div class="flex items-center gap-2">
                        <span>{{ t('agent.sameAsLLMModel') }}</span>
                      </div>
                    </SelectItem>
                    <SelectItem v-for="provider in providers" :key="provider.id" :value="provider.id">
                      <div class="flex items-center gap-2">
                        <span>{{ provider.name }} ({{ provider.model }})</span>
                        <div class="flex items-center gap-1 ml-2">
                          <span class="inline-flex items-center justify-center w-4 h-4 text-[10px] font-medium bg-primary/10 text-primary rounded">T</span>
                          <ImageIcon v-if="provider.supports_multimodal" class="w-4 h-4 text-primary" />
                        </div>
                      </div>
                    </SelectItem>
                  </SelectContent>
                </Select>
                <p class="text-xs text-muted-foreground mt-1">{{ t('agent.fastModelDescription') }}</p>
              </FormItem>

              <FormItem :label="t('agentEdit.enableMultimodal')">
                <div class="flex items-center h-10 gap-3 border rounded-md px-3 bg-background">
                  <Switch
                    :checked="store.formData.enableMultimodal"
                    @update:checked="(v) => store.formData.enableMultimodal = v"
                    :disabled="!selectedProviderSupportsMultimodal"
                  />
                  <span class="text-sm text-muted-foreground">
                    {{ store.formData.enableMultimodal ? t('agentEdit.multimodalEnabled') : t('agentEdit.multimodalDisabled') }}
                    <span v-if="!selectedProviderSupportsMultimodal" class="text-xs text-destructive ml-2">({{ t('agentEdit.multimodalUnsupported') }})</span>
                  </span>
                </div>
              </FormItem>
            </div>
          </section>

          <!-- Sub Agent Section -->
          <section id="subAgents" class="scroll-mt-6" v-if="store.formData.agentMode === 'fibre'">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Bot class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agentEdit.subAgents') }}</h2>
              </div>
            </div>
            <div class="pl-10">
              <FormItem :label="t('agentEdit.subAgents')">
                <div class="border rounded-lg overflow-hidden bg-background">
                  <div class="px-3 py-2 border-b bg-muted/30 flex items-center justify-between">
                    <span class="text-xs font-medium text-muted-foreground">{{ t('agentEdit.availableSubAgents') }} ({{ filteredAgents.length }})</span>
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-7 text-xs px-2"
                      @click="selectAllSubAgents"
                      :disabled="filteredAgents.length === 0"
                    >
                      {{ t('agentEdit.selectAll') }}
                    </Button>
                  </div>
                  <ScrollArea class="h-[200px]">
                    <div class="p-3">
                      <div class="flex flex-wrap gap-2">
                        <button
                          v-for="agent in filteredAgents"
                          :key="agent.id"
                          type="button"
                          class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm transition-all duration-200 border"
                          :class="isSubAgentSelected(agent.id)
                            ? 'bg-primary/10 border-primary/40 text-primary hover:bg-primary/20'
                            : 'bg-muted/30 border-muted hover:bg-muted/50 hover:border-muted-foreground/30'"
                          @click="toggleSubAgent(agent.id, !isSubAgentSelected(agent.id))"
                        >
                          <span
                            class="w-2 h-2 rounded-full"
                            :class="isSubAgentSelected(agent.id) ? 'bg-green-500' : 'bg-gray-400'"
                          ></span>
                          <span class="truncate max-w-[120px]">{{ agent.name }}</span>
                        </button>
                      </div>
                    </div>
                  </ScrollArea>
                </div>
              </FormItem>
            </div>
          </section>

          <!-- Tools Section -->
          <section id="tools" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Wrench class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.availableTools') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.toolsTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-2">
                <p class="text-xs text-muted-foreground">{{ t('agentEdit.toolsDesc') }}</p>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <div class="flex flex-col md:flex-row h-[400px] border rounded-lg overflow-hidden bg-muted/5">
                <!-- Left: Source Groups -->
                <div class="w-full md:w-48 border-b md:border-b-0 md:border-r bg-muted/20 flex flex-col shrink-0">
                  <div class="p-2 space-y-1 overflow-y-auto">
                    <button
                      v-for="group in groupedTools"
                      :key="group.source"
                      class="w-full text-left px-3 py-2 rounded-md text-sm transition-colors flex items-center gap-2"
                      :class="selectedGroupSource === group.source ? 'bg-primary/10 text-primary font-medium' : 'hover:bg-muted/50 text-muted-foreground/70'"
                      @click="selectedGroupSource = group.source"
                    >
                      <component :is="getGroupIcon(group.source)" class="h-3.5 w-3.5 shrink-0" />
                      <span class="truncate flex-1">{{ getToolSourceLabel(group.source) }}</span>
                      <span class="text-xs opacity-60">{{ group.tools.length }}</span>
                    </button>
                  </div>
                </div>

                <!-- Right: Tool List -->
                <div class="flex-1 bg-background flex flex-col min-w-0">
                  <div class="p-3 border-b flex items-center justify-between gap-3">
                    <div class="relative flex-1">
                      <Search class="absolute left-2 top-2 h-4 w-4 text-muted-foreground/70" />
                      <Input v-model="searchQueries.tools" :placeholder="t('agentEdit.searchTools')" class="pl-8 h-9" />
                    </div>
                    <div class="flex items-center gap-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        class="h-8 text-xs px-2"
                        @click="selectAllToolsInGroup"
                        :disabled="displayedTools.length === 0"
                      >
                        {{ t('agentEdit.selectAll') }}
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        class="h-8 text-xs px-2"
                        @click="deselectAllToolsInGroup"
                        :disabled="displayedTools.length === 0"
                      >
                        {{ t('agentEdit.deselectAll') }}
                      </Button>
                    </div>
                  </div>
                  <ScrollArea class="flex-1">
                    <div class="p-4 space-y-2">
                      <div v-for="tool in displayedTools" :key="tool.name" class="flex items-start gap-3 p-3 rounded-lg border border-muted/50 hover:bg-accent/5 transition-colors">
                        <Checkbox 
                          :id="`tool-${tool.name}`" 
                          :checked="isRequiredTool(tool.name) || store.formData.availableTools.includes(tool.name)" 
                          :disabled="isRequiredTool(tool.name)"
                          @update:checked="() => handleToolToggle(tool.name)" 
                          class="mt-0.5"
                        />
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2">
                            <label :for="`tool-${tool.name}`" class="text-sm font-medium cursor-pointer" :class="{ 'opacity-50': isRequiredTool(tool.name) }">
                              {{ tool.name }}
                            </label>
                            <Badge v-if="isRequiredTool(tool.name)" variant="secondary" class="text-[10px] h-5 px-1.5">{{ t('agentEdit.badge.skillRequired') }}</Badge>
                          </div>
                          <p v-if="tool.description" class="text-xs text-muted-foreground line-clamp-2 mt-1">
                            {{ tool.description }}
                          </p>
                        </div>
                      </div>
                    </div>
                  </ScrollArea>
                </div>
              </div>
            </div>
          </section>

          <!-- Skills Section -->
          <section id="skills" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Bot class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.availableSkills') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.skillsTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-auto flex items-center gap-2">
                <span class="text-xs text-muted-foreground">({{ store.formData.availableSkills?.length || 0 }})</span>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <!-- Selected Skills Tags -->
              <div v-if="selectedSkills.length > 0" class="flex flex-wrap gap-2 p-3 border rounded-lg bg-muted/5">
                <Badge
                  v-for="skill in selectedSkills"
                  :key="skill.name || skill"
                  variant="secondary"
                  class="text-xs px-2 py-1 h-auto cursor-pointer hover:bg-destructive/10 hover:text-destructive transition-colors"
                  @click="store.toggleSkill(skill.name || skill)"
                >
                  {{ skill.name || skill }}
                  <X class="h-3 w-3 ml-1" />
                </Badge>
              </div>
              
              <!-- Skills Selection Area -->
              <div class="h-[350px] border rounded-lg overflow-hidden bg-muted/5">
                <div class="p-3 border-b flex items-center justify-between gap-3">
                  <div class="relative flex-1">
                    <Search class="absolute left-2 top-2 h-4 w-4 text-muted-foreground/70" />
                    <Input v-model="searchQueries.skills" :placeholder="t('agentEdit.searchSkills')" class="pl-8 h-9" />
                  </div>
                  <div class="flex items-center gap-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 text-xs px-2"
                      @click="selectAllSkills"
                      :disabled="filteredSkills.length === 0"
                    >
                      {{ t('agentEdit.selectAll') }}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 text-xs px-2"
                      @click="deselectAllSkills"
                      :disabled="store.formData.availableSkills?.length === 0"
                    >
                      {{ t('agentEdit.deselectAll') }}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 text-xs px-2"
                      @click="refreshSkills"
                      :disabled="!props.agent?.id || loadingAgentSkills"
                    >
                      <RefreshCw class="h-3 w-3 mr-1" :class="{ 'animate-spin': loadingAgentSkills }" />
                      {{ t('agentEdit.refreshSkills') || '刷新' }}
                    </Button>
                  </div>
                </div>
                <ScrollArea class="h-[calc(350px-57px)]">
                  <div class="p-4 space-y-2">
                    <div v-for="skill in filteredSkills" :key="skill.name || skill" 
                      class="flex items-start gap-3 p-3 rounded-lg border border-muted/50 hover:bg-accent/5 transition-colors"
                      :class="{ 'cursor-pointer': !isSkillSyncing(skill.name || skill) }"
                    >
                      <Checkbox 
                        :id="`skill-${skill.name || skill}`" 
                        :checked="store.formData.availableSkills?.includes(skill.name || skill)" 
                        @update:checked="() => !isSkillSyncing(skill.name || skill) && store.toggleSkill(skill.name || skill)" 
                        class="mt-0.5 pointer-events-none"
                      />
                      <div class="flex-1 min-w-0" @click="!isSkillSyncing(skill.name || skill) && store.toggleSkill(skill.name || skill)">
                        <div class="flex items-center gap-2">
                          <label :for="`skill-${skill.name || skill}`" class="text-sm font-medium cursor-pointer pointer-events-none">
                            {{ skill.name || skill }}
                          </label>
                          <!-- 待更新标签 -->
                          <Badge 
                            v-if="skill.need_update" 
                            variant="destructive" 
                            class="text-[10px] h-5 px-1.5"
                          >
                            <Loader v-if="isSkillSyncing(skill.name || skill)" class="h-3 w-3 mr-1 animate-spin" />
                            {{ t('agentEdit.skillPendingUpdate') || '待更新' }}
                          </Badge>
                        </div>
                        <p v-if="skill.description" class="text-xs text-muted-foreground line-clamp-2 mt-1">{{ skill.description }}</p>
                      </div>
                      <!-- 更新按钮 -->
                      <Button
                        v-if="skill.need_update && !isSkillSyncing(skill.name || skill)"
                        variant="ghost"
                        size="sm"
                        class="h-7 text-xs px-2 text-primary hover:text-primary hover:bg-primary/10"
                        @click.stop="syncSkill(skill.name || skill)"
                      >
                        <RefreshCw class="h-3 w-3 mr-1" />
                        {{ t('agentEdit.updateSkill') || '更新' }}
                      </Button>
                    </div>
                  </div>
                </ScrollArea>
              </div>
            </div>
          </section>

          <!-- Knowledge Bases Section -->
          <section id="knowledgeBases" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Database class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.availableKnowledgeBases') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.knowledgeTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-auto flex items-center gap-2">
                <span class="text-xs text-muted-foreground">({{ store.formData.availableKnowledgeBases?.length || 0 }})</span>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <div class="h-[350px] border rounded-lg overflow-hidden bg-muted/5">
                <div class="p-3 border-b flex items-center justify-between gap-3">
                  <div class="relative flex-1">
                    <Search class="absolute left-2 top-2 h-4 w-4 text-muted-foreground/70" />
                    <Input v-model="searchQueries.knowledgeBases" :placeholder="t('agentEdit.searchKnowledgeBases')" class="pl-8 h-9" />
                  </div>
                  <div class="flex items-center gap-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 text-xs px-2"
                      @click="selectAllKnowledgeBases"
                      :disabled="filteredKnowledgeBases.length === 0"
                    >
                      {{ t('agentEdit.selectAll') }}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 text-xs px-2"
                      @click="deselectAllKnowledgeBases"
                      :disabled="store.formData.availableKnowledgeBases?.length === 0"
                    >
                      {{ t('agentEdit.deselectAll') }}
                    </Button>
                  </div>
                </div>
                <ScrollArea class="h-[calc(350px-57px)]">
                  <div class="p-4 space-y-2">
                    <div v-for="kb in filteredKnowledgeBases" :key="kb.id" 
                      class="flex items-start gap-3 p-3 rounded-lg border border-muted/50 hover:bg-accent/5 transition-colors cursor-pointer"
                      @click="toggleKnowledgeBase(kb.id)"
                    >
                      <Checkbox 
                        :id="`kb-${kb.id}`" 
                        :checked="store.formData.availableKnowledgeBases?.includes(kb.id)" 
                        @update:checked="() => toggleKnowledgeBase(kb.id)" 
                        class="mt-0.5 pointer-events-none"
                      />
                      <div class="flex-1 min-w-0">
                        <label :for="`kb-${kb.id}`" class="text-sm font-medium cursor-pointer pointer-events-none">
                          {{ kb.name }}
                        </label>
                        <p v-if="kb.intro" class="text-xs text-muted-foreground line-clamp-2 mt-1">{{ kb.intro }}</p>
                      </div>
                    </div>
                  </div>
                </ScrollArea>
              </div>
            </div>
          </section>

          <section id="im" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <MessageSquare class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agentEdit.imChannels') }}</h2>
              </div>
              <div class="ml-auto flex items-center gap-2">
                <span class="text-xs text-muted-foreground">({{ enabledIMChannelsCount }})</span>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <div v-if="!store.formData.id" class="rounded-lg border bg-muted/20 px-4 py-3 text-sm text-muted-foreground">
                {{ t('agentEdit.agentNotSaved') }}
              </div>
              <template v-else>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
                  <Button
                    v-for="provider in imProviders"
                    :key="provider.key"
                    variant="outline"
                    size="sm"
                    class="justify-start"
                    :class="activeIMProvider === provider.key ? 'border-primary text-primary bg-primary/5' : ''"
                    @click="activeIMProvider = provider.key"
                  >
                    {{ provider.label }}
                  </Button>
                </div>

                <div v-if="isLoadingIMConfig" class="rounded-lg border bg-muted/10 p-4">
                  <div class="flex items-center gap-2 text-sm text-muted-foreground">
                    <Loader class="h-4 w-4 animate-spin" />
                    {{ t('agentEdit.loading') || '加载中...' }}
                  </div>
                </div>

                <div v-else class="space-y-4">
                  <div
                    v-for="provider in imProviders"
                    v-show="activeIMProvider === provider.key"
                    :key="`im-provider-${provider.key}`"
                    class="space-y-4"
                  >
                    <div class="flex flex-col gap-3 rounded-lg border bg-muted/10 p-4 md:flex-row md:items-center md:justify-between">
                      <div class="space-y-1">
                        <div class="text-sm font-medium">{{ provider.label }}</div>
                        <p class="text-xs text-muted-foreground">{{ getIMProviderDescription(provider.key) }}</p>
                      </div>
                      <div class="flex flex-wrap items-center gap-3">
                        <Button
                          variant="outline"
                          size="sm"
                          @click="testIMConnection(provider.key)"
                          :disabled="testingIM[provider.key]"
                        >
                          <Loader v-if="testingIM[provider.key]" class="mr-2 h-3.5 w-3.5 animate-spin" />
                          <Play v-else class="mr-2 h-3.5 w-3.5" />
                          {{ t('agentEdit.testConnection') }}
                        </Button>
                        <div class="flex items-center gap-2">
                          <Label class="text-xs text-muted-foreground">{{ t('agentEdit.enableProvider') }}</Label>
                          <Switch
                            :checked="imConfig[provider.key]?.enabled"
                            :disabled="!canToggleProvider(provider.key)"
                            @update:checked="(checked) => handleEnableSwitch(provider.key, checked)"
                          />
                        </div>
                      </div>
                    </div>

                    <div class="rounded-lg border px-4 py-3 text-sm" :class="getIMStatusClass(provider.key)">
                      {{ getIMStatusText(provider.key) }}
                    </div>

                    <div v-if="provider.key === 'wechat_work'" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <FormItem :label="t('agentEdit.imPlaceholder.wechatWorkBotId')">
                        <Input
                          v-model="imConfig.wechat_work.config.bot_id"
                          :placeholder="t('agentEdit.imPlaceholder.wechatWorkBotId')"
                          :disabled="imConfig.wechat_work.enabled || testingIM.wechat_work"
                          class="h-10"
                        />
                      </FormItem>
                      <FormItem :label="t('agentEdit.imPlaceholder.secret')">
                        <Input
                          v-model="imConfig.wechat_work.config.secret"
                          :placeholder="t('agentEdit.imPlaceholder.secret')"
                          :disabled="imConfig.wechat_work.enabled || testingIM.wechat_work"
                          class="h-10"
                        />
                      </FormItem>
                    </div>

                    <div v-if="provider.key === 'wechat_personal'" class="space-y-4">
                      <div class="rounded-lg border bg-background p-4 space-y-3">
                        <p class="text-sm text-muted-foreground">{{ t('agentEdit.wechatPersonalIntro') }}</p>
                        <div class="flex flex-wrap items-center gap-2">
                          <Button
                            variant="outline"
                            size="sm"
                            @click="startWeChatPersonalLogin"
                            :disabled="wechatPersonalLogin.loading || imConfig.wechat_personal.enabled"
                          >
                            <Loader v-if="wechatPersonalLogin.loading" class="mr-2 h-3.5 w-3.5 animate-spin" />
                            <QrCode v-else class="mr-2 h-3.5 w-3.5" />
                            {{ t('agentEdit.wechatPersonalScanToken') }}
                          </Button>
                          <span v-if="wechatPersonalLogin.status" class="text-xs text-muted-foreground">
                            {{ getWeChatPersonalStatusText() }}
                          </span>
                        </div>
                        <div v-if="wechatPersonalLogin.qrUrl" class="space-y-2">
                          <a
                            :href="wechatPersonalLogin.qrUrl"
                            target="_blank"
                            rel="noreferrer"
                            class="block break-all text-xs text-primary underline"
                          >
                            {{ wechatPersonalLogin.qrUrl }}
                          </a>
                          <Button variant="ghost" size="sm" class="h-8 px-2 text-xs" @click="copyWeChatPersonalUrl">
                            <Copy class="mr-1.5 h-3.5 w-3.5" />
                            {{ t('agentEdit.wechatPersonalCopyLink') }}
                          </Button>
                        </div>
                      </div>

                      <FormItem :label="t('agentEdit.imPlaceholder.botToken')">
                        <Textarea
                          v-model="imConfig.wechat_personal.config.bot_token"
                          :rows="3"
                          :placeholder="t('agentEdit.imPlaceholder.botToken')"
                          :disabled="imConfig.wechat_personal.enabled || testingIM.wechat_personal"
                        />
                      </FormItem>
                      <FormItem :label="t('agentEdit.imPlaceholder.botId')">
                        <Input
                          v-model="imConfig.wechat_personal.config.bot_id"
                          :placeholder="t('agentEdit.imPlaceholder.botId')"
                          :disabled="imConfig.wechat_personal.enabled || testingIM.wechat_personal"
                          class="h-10"
                        />
                      </FormItem>
                    </div>

                    <div v-if="provider.key === 'dingtalk'" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <FormItem :label="t('agentEdit.imPlaceholder.dingtalkClientId')">
                        <Input
                          v-model="imConfig.dingtalk.config.client_id"
                          :placeholder="t('agentEdit.imPlaceholder.dingtalkClientId')"
                          :disabled="imConfig.dingtalk.enabled || testingIM.dingtalk"
                          class="h-10"
                        />
                      </FormItem>
                      <FormItem :label="t('agentEdit.imPlaceholder.clientSecret')">
                        <Input
                          v-model="imConfig.dingtalk.config.client_secret"
                          :placeholder="t('agentEdit.imPlaceholder.clientSecret')"
                          :disabled="imConfig.dingtalk.enabled || testingIM.dingtalk"
                          class="h-10"
                        />
                      </FormItem>
                    </div>

                    <div v-if="provider.key === 'feishu'" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <FormItem :label="t('agentEdit.imPlaceholder.feishuAppId')">
                        <Input
                          v-model="imConfig.feishu.config.app_id"
                          :placeholder="t('agentEdit.imPlaceholder.feishuAppId')"
                          :disabled="imConfig.feishu.enabled || testingIM.feishu"
                          class="h-10"
                        />
                      </FormItem>
                      <FormItem :label="t('agentEdit.imPlaceholder.appSecret')">
                        <Input
                          v-model="imConfig.feishu.config.app_secret"
                          :placeholder="t('agentEdit.imPlaceholder.appSecret')"
                          :disabled="imConfig.feishu.enabled || testingIM.feishu"
                          class="h-10"
                        />
                      </FormItem>
                    </div>

                    <div v-if="provider.key === 'imessage'" class="space-y-4">
                      <FormItem :label="t('agentEdit.imessageAllowedSenders')">
                        <Textarea
                          :model-value="(imConfig.imessage.config.allowed_senders || []).join('\n')"
                          :rows="5"
                          :placeholder="t('agentEdit.imessageAllowedSendersHint')"
                          :disabled="imConfig.imessage.enabled || testingIM.imessage"
                          @input="updateIMessageAllowedSenders($event.target.value)"
                        />
                      </FormItem>
                    </div>
                  </div>
                </div>
              </template>
            </div>
          </section>

          <!-- System Context Section -->
          <section id="context" class="scroll-mt-6">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <FileText class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.systemContext') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.systemContextTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-auto flex items-center gap-2">
                <span class="text-xs text-muted-foreground">({{ store.systemContextPairs.filter(p => p.key).length }})</span>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <div v-for="(pair, index) in store.systemContextPairs" :key="index" class="flex items-center gap-3">
                <Input
                  :model-value="pair.key"
                  :placeholder="t('agent.contextKey')"
                  @input="store.updateSystemContextPair(index, 'key', $event.target.value)"
                  class="flex-1 h-9"
                />
                <Input
                  :model-value="pair.value"
                  :placeholder="t('agent.contextValue')"
                  @input="store.updateSystemContextPair(index, 'value', $event.target.value)"
                  class="flex-1 h-9"
                />
                <Button
                  variant="ghost"
                  size="icon"
                  class="h-9 w-9 text-destructive hover:text-destructive hover:bg-destructive/10"
                  @click="store.removeSystemContextPair(index)"
                  :disabled="store.systemContextPairs.length === 1 && !pair.key && !pair.value"
                >
                  <Trash2 class="h-3.5 w-3.5" />
                </Button>
              </div>
              <Button variant="outline" size="sm" class="w-full border-dashed h-9" @click="store.addSystemContextPair">
                <Plus class="h-3.5 w-3.5 mr-2" /> {{ t('agent.addContext') }}
              </Button>
            </div>
          </section>

          <!-- Workflows Section -->
          <section id="workflows" class="scroll-mt-6 pb-8">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                <Workflow class="h-4 w-4 text-primary" />
              </div>
              <div class="flex items-center gap-2">
                <h2 class="text-base font-semibold">{{ t('agent.workflows') }}</h2>
                <TooltipProvider>
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <button class="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs hover:bg-muted/80 transition-colors">
                        ?
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p class="text-xs">{{ t('agentEdit.workflowsTooltip') }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <div class="ml-2">
                <p class="text-xs text-muted-foreground">{{ t('agentEdit.workflowsDesc') }}</p>
                <span class="text-xs text-muted-foreground">({{ store.workflowPairs.filter(w => w.key).length }})</span>
              </div>
            </div>
            <div class="pl-10 space-y-4">
              <div v-for="(workflow, index) in store.workflowPairs" :key="workflow.id || index" class="border border-muted/50 rounded-lg p-4 bg-muted/5">
                <div class="flex items-center gap-2 mb-3">
                  <Button variant="ghost" size="sm" class="h-8 w-8 p-0" @click="toggleWorkflow(workflow.id)">
                    <ChevronDown v-if="isWorkflowExpanded(workflow.id)" class="h-4 w-4" />
                    <ChevronRight v-else class="h-4 w-4" />
                  </Button>
                  <Input
                    :model-value="workflow.key"
                    :placeholder="t('agent.workflowName')"
                    class="flex-1 h-9"
                    @input="store.updateWorkflowPair(index, 'key', $event.target.value)"
                  />
                  <Button
                    variant="ghost"
                    size="icon"
                    class="h-8 w-8 text-destructive hover:text-destructive"
                    @click="store.removeWorkflowPair(index)"
                  >
                    <Trash2 class="h-3.5 w-3.5" />
                  </Button>
                </div>
                <div v-show="isWorkflowExpanded(workflow.id)" class="pl-10 space-y-3">
                  <div v-for="(step, stepIndex) in workflow.steps" :key="stepIndex" class="flex items-start gap-2">
                    <Textarea
                      :model-value="step"
                      :placeholder="`${t('agent.step')} ${stepIndex + 1}`"
                      class="flex-1 min-h-[60px] resize-y"
                      @input="store.updateWorkflowStep(index, stepIndex, $event.target.value)"
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      class="h-8 w-8 mt-1 text-destructive hover:text-destructive"
                      @click="store.removeWorkflowStep(index, stepIndex)"
                      :disabled="workflow.steps.length === 1"
                    >
                      <Trash2 class="h-3 w-3" />
                    </Button>
                  </div>
                  <Button variant="outline" size="sm" class="w-full border-dashed h-9" @click="store.addWorkflowStep(index)">
                    <Plus class="h-3 w-3 mr-2" /> {{ t('agent.addStep') }}
                  </Button>
                </div>
              </div>
              <Button variant="outline" size="sm" class="w-full border-dashed h-9" @click="handleAddWorkflow">
                <Plus class="h-3.5 w-3.5 mr-2" /> {{ t('agent.addWorkflow') }}
              </Button>
            </div>
          </section>
        </div>
      </div>
    </div>

    <!-- Optimize Modal -->
    <Dialog :open="showOptimizeModal" @update:open="v => !v && handleOptimizeCancel()">
      <DialogContent class="sm:max-w-[640px]">
        <DialogHeader>
          <DialogTitle>{{ t('agentEdit.optimizeTitle') }}</DialogTitle>
          <DialogDescription>{{ t('agentEdit.optimizeDesc') }}</DialogDescription>
        </DialogHeader>
        <div class="space-y-4 py-4">
          <div class="space-y-2">
            <Label>{{ t('agentEdit.optimizeGoal') }} <span class="text-xs text-muted-foreground">({{ t('agentEdit.optional') }})</span></Label>
            <Textarea v-model="optimizationGoal" :rows="3" :placeholder="t('agentEdit.optimizeGoalPlaceholder')" :disabled="isOptimizing || !!optimizedResult" />
          </div>
          <div v-if="optimizedResult" class="space-y-2">
            <Label>{{ t('agentEdit.optimizePreview') }} <span class="text-xs text-muted-foreground">（{{ t('agentEdit.editable') }}）</span></Label>
            <Textarea v-model="optimizedResult" :rows="8" :placeholder="t('agentEdit.optimizePreviewPlaceholder')" />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" @click="handleOptimizeCancel">{{ t('common.cancel') }}</Button>
          <template v-if="optimizedResult">
            <Button variant="outline" @click="handleResetOptimization">{{ t('agentEdit.reOptimize') }}</Button>
            <Button @click="handleApplyOptimization">{{ t('agentEdit.applyOptimization') }}</Button>
          </template>
          <template v-else>
            <Button @click="handleOptimizeStart" :disabled="isOptimizing">
              <Loader v-if="isOptimizing" class="mr-2 h-4 w-4 animate-spin" />
              {{ t('agentEdit.startOptimization') }}
            </Button>
          </template>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed, watch, onBeforeUnmount, nextTick } from 'vue'
import { useAgentEditStore } from '../stores/agentEdit'
import { useLanguage } from '../utils/i18n.js'
import { getMcpServerLabel } from '../utils/mcpLabels.js'
import { agentAPI } from '../api/agent.js'
import request from '../utils/request.js'
import { modelProviderAPI } from '@/api/modelProvider'
import { skillAPI } from '../api/skill.js'
import { toast } from 'vue-sonner'
import { 
  Loader, ChevronLeft, ChevronRight, ChevronDown, Save, Check, Plus, Trash2, 
  Sparkles, Bot, Wrench, Search, Server, Code, User, Cpu, Database, Workflow,
  FileText, X, Image as ImageIcon, RefreshCw, MessageSquare, Play, QrCode, Copy
} from 'lucide-vue-next'

// UI Components
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Button } from '@/components/ui/button'
import { FormItem } from '@/components/ui/form'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Switch } from '@/components/ui/switch'
import { Checkbox } from '@/components/ui/checkbox'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

const props = defineProps({
  visible: { type: Boolean, default: false },
  agent: { type: Object, default: null },
  tools: { type: Array, default: () => [] },
  skills: { type: Array, default: () => [] },
  knowledgeBases: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:visible', 'save'])
const store = useAgentEditStore()
const { t } = useLanguage()
const { listModelProviders } = modelProviderAPI

const saving = ref(false)
const contentRef = ref(null)
const activeSection = ref('basic')
const agentSkills = ref([])
const loadingAgentSkills = ref(false)

const IM_TOOLS = ['send_message_through_im', 'send_file_through_im', 'send_image_through_im']
const IM_PROVIDERS = ['wechat_work', 'wechat_personal', 'dingtalk', 'feishu', 'imessage']

const createDefaultIMConfig = () => ({
  wechat_work: { enabled: false, config: { bot_id: '', secret: '' } },
  wechat_personal: { enabled: false, config: { bot_token: '', bot_id: '' } },
  dingtalk: { enabled: false, config: { client_id: '', client_secret: '' } },
  feishu: { enabled: false, config: { app_id: '', app_secret: '' } },
  imessage: { enabled: false, config: { allowed_senders: [] } }
})

const createDefaultIMTestStatus = () => Object.fromEntries(
  IM_PROVIDERS.map(provider => [provider, { tested: false, passed: false, message: '' }])
)

const createDefaultFrozenConfig = () => Object.fromEntries(
  IM_PROVIDERS.map(provider => [provider, null])
)

const activeIMProvider = ref('wechat_work')
const isLoadingIMConfig = ref(false)
const imConfig = ref(createDefaultIMConfig())
const testingIM = ref({})
const imTestStatus = ref(createDefaultIMTestStatus())
const imFrozenConfig = ref(createDefaultFrozenConfig())
const wechatPersonalLogin = ref({
  loading: false,
  qrcode: '',
  qrUrl: '',
  status: '',
  polling: false
})

// 技能同步状态
const syncingSkills = ref(new Set())  // 正在同步的技能名称集合

// 检查技能是否正在同步
const isSkillSyncing = (skillName) => {
  return syncingSkills.value.has(skillName)
}

// 同步技能到Agent工作空间
const syncSkill = async (skillName) => {
  if (!props.agent?.id) {
    toast.error(t('agentEdit.agentNotSaved') || '请先保存Agent')
    return
  }

  if (syncingSkills.value.has(skillName)) {
    return
  }

  syncingSkills.value.add(skillName)

  try {
    await skillAPI.syncSkillToAgent(skillName, props.agent.id)
    // 同步成功后，刷新技能列表
    await loadAgentAvailableSkills(props.agent.id)
    toast.success(t('agentEdit.skillSyncSuccess') || `技能 '${skillName}' 同步成功`)
  } catch (error) {
    console.error('Failed to sync skill:', error)
    toast.error(t('agentEdit.skillSyncFailed') || `技能 '${skillName}' 同步失败`)
  } finally {
    syncingSkills.value.delete(skillName)
  }
}

// Navigation sections
const sections = computed(() => {
  const items = [
    { id: 'basic', label: t('agent.basicInfo'), icon: User },
    { id: 'strategy', label: t('agent.strategy'), icon: Cpu },
    { id: 'model', label: t('agent.modelProvider'), icon: Server },
    { id: 'tools', label: t('agent.availableTools'), icon: Wrench },
    { id: 'skills', label: t('agent.availableSkills'), icon: Bot },
    { id: 'knowledgeBases', label: t('agent.availableKnowledgeBases'), icon: Database },
    { id: 'im', label: t('agentEdit.imChannels'), icon: MessageSquare },
    { id: 'context', label: t('agent.systemContext'), icon: FileText },
    { id: 'workflows', label: t('agent.workflows'), icon: Workflow },
  ]

  if (store.formData.agentMode === 'fibre') {
    items.splice(3, 0, { id: 'subAgents', label: t('agentEdit.subAgents'), icon: Bot })
  }

  return items
})

const isEditMode = computed(() => !!store.formData.id)

// Scroll to section
const scrollToSection = (sectionId) => {
  const element = document.getElementById(sectionId)
  if (element && contentRef.value) {
    const container = contentRef.value
    const elementTop = element.offsetTop - 24
    container.scrollTo({
      top: elementTop,
      behavior: 'smooth'
    })
  }
}

// Update active section on scroll
const handleScroll = () => {
  if (!contentRef.value) return
  
  const scrollTop = contentRef.value.scrollTop
  const sectionElements = sections.value.map(s => ({
    id: s.id,
    element: document.getElementById(s.id)
  })).filter(s => s.element)
  
  for (let i = sectionElements.length - 1; i >= 0; i--) {
    const section = sectionElements[i]
    if (section.element) {
      const offsetTop = section.element.offsetTop - 100
      if (scrollTop >= offsetTop) {
        activeSection.value = section.id
        break
      }
    }
  }
}

// 加载Agent可用技能列表
const loadAgentAvailableSkills = async (agentId) => {
  console.log('[SkillSync] loadAgentAvailableSkills called, agentId:', agentId)
  if (!agentId) {
    console.log('[SkillSync] No agentId, clearing agentSkills')
    agentSkills.value = []
    return
  }
  try {
    loadingAgentSkills.value = true
    console.log('[SkillSync] Calling API getAgentAvailableSkills...')
    const response = await skillAPI.getAgentAvailableSkills(agentId)
    console.log('[SkillSync] API response:', response)
    if (response.skills) {
      agentSkills.value = response.skills
      console.log('[SkillSync] Loaded skills count:', response.skills.length)
      // 检查是否有需要更新的技能
      const needUpdateSkills = response.skills.filter(s => s.need_update)
      console.log('[SkillSync] Skills need update:', needUpdateSkills.map(s => s.name))
    } else {
      console.log('[SkillSync] No skills in response')
      agentSkills.value = []
    }
  } catch (error) {
    console.error('[SkillSync] Failed to load agent available skills:', error)
    // 出错时清空列表，不要回退到props.skills（因为props.skills没有need_update字段）
    agentSkills.value = []
    toast.error(t('agentEdit.loadSkillsFailed') || '加载技能列表失败')
  } finally {
    loadingAgentSkills.value = false
  }
}

// 刷新技能列表
const refreshSkills = async () => {
  if (!props.agent?.id) return
  await loadAgentAvailableSkills(props.agent.id)
}

const cloneDeep = (value) => JSON.parse(JSON.stringify(value))

const hasMeaningfulValue = (value) => {
  if (Array.isArray(value)) {
    return value.some(item => hasMeaningfulValue(item))
  }
  if (value === null || value === undefined) {
    return false
  }
  if (typeof value === 'string') {
    return value.trim().length > 0
  }
  return Boolean(value)
}

const getIMProviderLabel = (provider) => {
  const labelMap = {
    wechat_work: 'agentEdit.imProvider.wechatWork',
    wechat_personal: 'agentEdit.imProvider.wechatPersonal',
    dingtalk: 'agentEdit.imProvider.dingtalk',
    feishu: 'agentEdit.imProvider.feishu',
    imessage: 'agentEdit.imProvider.imessage'
  }
  return t(labelMap[provider]) || provider
}

const enabledIMChannelsCount = computed(() => IM_PROVIDERS.filter(provider => imConfig.value[provider]?.enabled).length)
const hasEnabledIMChannel = computed(() => enabledIMChannelsCount.value > 0)
const imProviders = computed(() => IM_PROVIDERS.map(provider => ({ key: provider, label: getIMProviderLabel(provider) })))

const cloneProviderConfig = (provider) => cloneDeep(imConfig.value[provider]?.config || {})

const hasProviderConfig = (provider) => {
  const config = imConfig.value[provider]?.config || {}
  return Object.values(config).some(value => hasMeaningfulValue(value))
}

const isConfigFrozen = (provider) => JSON.stringify(imFrozenConfig.value[provider] || {}) === JSON.stringify(cloneProviderConfig(provider))
const canEnableProvider = (provider) => Boolean(imTestStatus.value[provider]?.passed) && isConfigFrozen(provider)
const canToggleProvider = (provider) => Boolean(imConfig.value[provider]?.enabled) || canEnableProvider(provider)

const getIMStatusText = (provider) => {
  if (imConfig.value[provider]?.enabled) {
    return t('agentEdit.imChannelEnabled')
  }

  if (canEnableProvider(provider)) {
    return imTestStatus.value[provider]?.message || t('agentEdit.testSuccess')
  }

  if (imTestStatus.value[provider]?.tested && !imTestStatus.value[provider]?.passed) {
    return imTestStatus.value[provider]?.message || t('agentEdit.testFailed')
  }

  if (hasProviderConfig(provider) && imFrozenConfig.value[provider] && !isConfigFrozen(provider)) {
    return t('agentEdit.retestAfterChange')
  }

  return t('agentEdit.fillAndTestFirst')
}

const getIMStatusClass = (provider) => {
  if (imConfig.value[provider]?.enabled) {
    return 'border-primary/20 bg-primary/5 text-primary'
  }
  if (canEnableProvider(provider)) {
    return 'border-emerald-500/20 bg-emerald-500/5 text-emerald-700 dark:text-emerald-300'
  }
  if (imTestStatus.value[provider]?.tested && !imTestStatus.value[provider]?.passed) {
    return 'border-destructive/20 bg-destructive/5 text-destructive'
  }
  return 'border-muted/60 bg-muted/20 text-muted-foreground'
}

const getIMProviderDescription = (provider) => {
  if (provider === 'wechat_personal') {
    return t('agentEdit.wechatPersonalIntro')
  }
  if (provider === 'imessage') {
    return t('agentEdit.imessageIntro')
  }
  return getIMStatusText(provider)
}

const updateIMessageAllowedSenders = (value) => {
  imConfig.value.imessage.config.allowed_senders = value
    .split('\n')
    .map(item => item.trim())
    .filter(Boolean)
}

const setIMChannelsOnForm = () => {
  const channels = {}
  IM_PROVIDERS.forEach(provider => {
    const providerConfig = cloneProviderConfig(provider)
    if (imConfig.value[provider]?.enabled || Object.values(providerConfig).some(value => hasMeaningfulValue(value))) {
      channels[provider] = {
        enabled: Boolean(imConfig.value[provider]?.enabled),
        config: providerConfig
      }
    }
  })
  store.formData.im_channels = channels
}

const syncIMTools = () => {
  if (!Array.isArray(store.formData.availableTools)) {
    store.formData.availableTools = []
  }

  const currentTools = [...store.formData.availableTools]
  const nextTools = currentTools.filter(toolName => !IM_TOOLS.includes(toolName))

  if (hasEnabledIMChannel.value) {
    IM_TOOLS.forEach(toolName => {
      if (!nextTools.includes(toolName)) {
        nextTools.push(toolName)
      }
    })
  }

  const changed =
    currentTools.length !== nextTools.length ||
    currentTools.some(toolName => !nextTools.includes(toolName)) ||
    nextTools.some(toolName => !currentTools.includes(toolName))

  if (changed) {
    store.formData.availableTools = nextTools
  }

  setIMChannelsOnForm()
  return changed
}

const autoSaveAgentConfig = async () => {
  if (!store.formData.id) {
    return
  }
  store.prepareForSave()
  const plainData = JSON.parse(JSON.stringify(store.formData))
  await agentAPI.updateAgent(store.formData.id, plainData)
}

const resetIMConfig = () => {
  imConfig.value = createDefaultIMConfig()
  testingIM.value = {}
  imTestStatus.value = createDefaultIMTestStatus()
  imFrozenConfig.value = createDefaultFrozenConfig()
  wechatPersonalLogin.value = {
    loading: false,
    qrcode: '',
    qrUrl: '',
    status: '',
    polling: false
  }
  activeIMProvider.value = 'wechat_work'
  setIMChannelsOnForm()
}

const applyLoadedIMConfig = (channels = {}) => {
  const nextConfig = createDefaultIMConfig()
  const nextTestStatus = createDefaultIMTestStatus()
  const nextFrozenConfig = createDefaultFrozenConfig()

  IM_PROVIDERS.forEach(provider => {
    const channel = channels[provider]
    if (!channel) {
      return
    }

    nextConfig[provider] = {
      enabled: Boolean(channel.enabled),
      config: {
        ...nextConfig[provider].config,
        ...(channel.config || {})
      }
    }

    const providerHasConfig = Object.values(nextConfig[provider].config).some(value => hasMeaningfulValue(value))
    if (providerHasConfig) {
      nextFrozenConfig[provider] = cloneDeep(nextConfig[provider].config)
      nextTestStatus[provider] = {
        tested: true,
        passed: true,
        message: t('agentEdit.testSuccess')
      }
    }
  })

  imConfig.value = nextConfig
  testingIM.value = {}
  imTestStatus.value = nextTestStatus
  imFrozenConfig.value = nextFrozenConfig
  wechatPersonalLogin.value = {
    loading: false,
    qrcode: '',
    qrUrl: '',
    status: '',
    polling: false
  }
  activeIMProvider.value =
    IM_PROVIDERS.find(provider => nextConfig[provider].enabled) ||
    IM_PROVIDERS.find(provider => Object.values(nextConfig[provider].config).some(value => hasMeaningfulValue(value))) ||
    'wechat_work'
  setIMChannelsOnForm()
}

const loadIMConfig = async (agentId = store.formData.id) => {
  if (!agentId) {
    resetIMConfig()
    return
  }

  isLoadingIMConfig.value = true
  try {
    const result = await request.get(`/api/im/agent/${agentId}/im_channels`)
    applyLoadedIMConfig(result?.channels || {})
    const toolsChanged = syncIMTools()
    if (toolsChanged) {
      try {
        await autoSaveAgentConfig()
      } catch (saveError) {
        console.error('Failed to auto save agent after loading IM config:', saveError)
      }
    }
  } catch (error) {
    console.error('Failed to load IM config:', error)
    resetIMConfig()
    toast.error(t('agentEdit.loadImConfigFailed') || '加载 IM 配置失败')
  } finally {
    isLoadingIMConfig.value = false
  }
}

const testIMConnection = async (provider) => {
  if (!store.formData.id) {
    toast.error(t('agentEdit.agentNotSaved') || '请先保存Agent')
    return
  }

  testingIM.value = { ...testingIM.value, [provider]: true }
  try {
    const result = await request.post(
      `/api/im/agent/${store.formData.id}/im_channels/${provider}/test`,
      { config: cloneProviderConfig(provider) }
    )

    if (result?.success) {
      imFrozenConfig.value = {
        ...imFrozenConfig.value,
        [provider]: cloneProviderConfig(provider)
      }
      imTestStatus.value = {
        ...imTestStatus.value,
        [provider]: {
          tested: true,
          passed: true,
          message: result.message || t('agentEdit.testSuccess')
        }
      }
      toast.success(result.message || t('agentEdit.testSuccess'))
      return
    }

    imTestStatus.value = {
      ...imTestStatus.value,
      [provider]: {
        tested: true,
        passed: false,
        message: result?.message || t('agentEdit.testFailed')
      }
    }
    toast.error(result?.message || t('agentEdit.testFailed'))
  } catch (error) {
    console.error('Failed to test IM connection:', error)
    imTestStatus.value = {
      ...imTestStatus.value,
      [provider]: {
        tested: true,
        passed: false,
        message: error.message || t('agentEdit.testFailed')
      }
    }
    toast.error(error.message || t('agentEdit.testFailed'))
  } finally {
    testingIM.value = { ...testingIM.value, [provider]: false }
  }
}

const saveIMChannelConfig = async (provider) => {
  if (!store.formData.id) {
    return false
  }

  try {
    await request.post(`/api/im/agent/${store.formData.id}/im_channels`, {
      [provider]: {
        enabled: Boolean(imConfig.value[provider]?.enabled),
        config: cloneProviderConfig(provider)
      }
    })
    setIMChannelsOnForm()
    return true
  } catch (error) {
    console.error('Failed to save IM config:', error)
    toast.error(error.message || t('agentEdit.saveConfigFailed'))
    return false
  }
}

const handleEnableSwitch = async (provider, checked) => {
  if (!store.formData.id) {
    toast.error(t('agentEdit.agentNotSaved') || '请先保存Agent')
    return
  }

  if (checked && !canEnableProvider(provider)) {
    toast.error(isConfigFrozen(provider) ? t('agentEdit.enableAfterTest') : t('agentEdit.retestAfterChange'))
    return
  }

  const previousEnabled = Boolean(imConfig.value[provider]?.enabled)
  imConfig.value[provider] = {
    ...imConfig.value[provider],
    enabled: checked
  }

  const saved = await saveIMChannelConfig(provider)
  if (!saved) {
    imConfig.value[provider] = {
      ...imConfig.value[provider],
      enabled: previousEnabled
    }
    return
  }

  const toolsChanged = syncIMTools()
  if (toolsChanged) {
    try {
      await autoSaveAgentConfig()
    } catch (error) {
      console.error('Failed to auto save agent after IM change:', error)
      toast.error(t('agentEdit.saveConfigFailed'))
    }
  }
}

const pollWeChatPersonalStatus = async (qrcode) => {
  if (!store.formData.id || !qrcode) {
    return
  }

  wechatPersonalLogin.value = {
    ...wechatPersonalLogin.value,
    polling: true
  }

  try {
    const result = await request.post(
      `/api/im/agent/${store.formData.id}/im_channels/wechat_personal/qrcode/status`,
      { qrcode },
      { timeout: 45000 }
    )
    const status = result?.status || 'wait'

    wechatPersonalLogin.value = {
      ...wechatPersonalLogin.value,
      status,
      polling: status !== 'confirmed' && status !== 'expired'
    }

    if (status === 'confirmed') {
      if (result?.bot_token) {
        imConfig.value.wechat_personal.config.bot_token = result.bot_token
      }
      if (result?.bot_id) {
        imConfig.value.wechat_personal.config.bot_id = result.bot_id
      }
      await testIMConnection('wechat_personal')
      return
    }

    if (status === 'expired') {
      return
    }

    if (wechatPersonalLogin.value.qrcode === qrcode) {
      setTimeout(() => {
        if (wechatPersonalLogin.value.qrcode === qrcode) {
          pollWeChatPersonalStatus(qrcode)
        }
      }, 1500)
    }
  } catch (error) {
    console.error('Failed to poll WeChat personal login status:', error)
    wechatPersonalLogin.value = {
      ...wechatPersonalLogin.value,
      polling: false
    }
  }
}

const startWeChatPersonalLogin = async () => {
  if (!store.formData.id) {
    toast.error(t('agentEdit.agentNotSaved') || '请先保存Agent')
    return
  }

  wechatPersonalLogin.value = {
    ...wechatPersonalLogin.value,
    loading: true,
    status: 'wait',
    polling: false
  }

  try {
    const result = await request.post(
      `/api/im/agent/${store.formData.id}/im_channels/wechat_personal/qrcode`,
      {}
    )

    if (!result?.qrcode || !result?.qrcode_url) {
      throw new Error(t('agentEdit.saveConfigFailed'))
    }

    wechatPersonalLogin.value = {
      loading: false,
      qrcode: result.qrcode,
      qrUrl: result.qrcode_url,
      status: 'wait',
      polling: false
    }

    pollWeChatPersonalStatus(result.qrcode)
  } catch (error) {
    console.error('Failed to start WeChat personal login:', error)
    wechatPersonalLogin.value = {
      ...wechatPersonalLogin.value,
      loading: false,
      polling: false,
      status: ''
    }
    toast.error(error.message || t('agentEdit.saveConfigFailed'))
  }
}

const getWeChatPersonalStatusText = () => {
  const status = wechatPersonalLogin.value.status
  if (status === 'scaned') {
    return t('agentEdit.wechatPersonalScanned')
  }
  if (status === 'confirmed') {
    return t('agentEdit.wechatPersonalConfirmed')
  }
  if (status === 'expired') {
    return t('agentEdit.wechatPersonalExpired')
  }
  return t('agentEdit.wechatPersonalLoading')
}

const copyWeChatPersonalUrl = async () => {
  if (!wechatPersonalLogin.value.qrUrl) {
    return
  }

  try {
    await navigator.clipboard.writeText(wechatPersonalLogin.value.qrUrl)
    toast.success(t('agentEdit.linkCopied'))
  } catch (error) {
    console.error('Failed to copy WeChat personal link:', error)
    toast.error(t('agentEdit.copyFailed'))
  }
}

// Initialize
onMounted(() => {
  store.initForm(props.agent)
  if (contentRef.value) {
    contentRef.value.addEventListener('scroll', handleScroll, { passive: true })
  }
  loadData()
  
  // 如果是编辑现有agent，加载agent可用技能列表
  if (props.agent && props.agent.id) {
    loadAgentAvailableSkills(props.agent.id)
    loadIMConfig(props.agent.id)
  } else {
    resetIMConfig()
  }
})

onBeforeUnmount(() => {
  if (contentRef.value) {
    contentRef.value.removeEventListener('scroll', handleScroll)
  }
})

// Watch agent changes
watch(() => props.agent, (newAgent) => {
  const isIdUpdate = newAgent && newAgent.id && store.formData.id === null && newAgent.name === store.formData.name
  const isSameAgent = newAgent && store.formData.id === newAgent.id
  
  if (isIdUpdate || isSameAgent) {
    store.initForm(newAgent, { preserveStep: true })
  } else {
    store.initForm(newAgent)
  }
  
  // 如果是编辑现有agent，加载agent可用技能列表
  if (newAgent && newAgent.id) {
    loadAgentAvailableSkills(newAgent.id)
    loadIMConfig(newAgent.id)
  } else {
    agentSkills.value = []
    resetIMConfig()
  }
}, { immediate: true })

// Data loading
const providers = ref([])
const allAgents = ref([])

// Default provider option
const defaultProviderOption = '__default__'
const llmProviderSelectValue = computed({
  get: () => store.formData.llm_provider_id ?? defaultProviderOption,
  set: (val) => {
    store.formData.llm_provider_id = val === defaultProviderOption ? null : val
    // Reset multimodal when provider changes
    store.formData.enableMultimodal = false
  }
})

// 快速模型选择（可选）
const fastLlmProviderSelectValue = computed({
  get: () => store.formData.fast_llm_provider_id ?? defaultProviderOption,
  set: (val) => {
    store.formData.fast_llm_provider_id = val === defaultProviderOption ? null : val
  }
})

// Check if selected provider supports multimodal
const selectedProviderSupportsMultimodal = computed(() => {
  const providerId = store.formData.llm_provider_id
  if (!providerId) return false
  const provider = providers.value.find(p => p.id === providerId)
  return provider?.supports_multimodal === true
})

const loadData = async () => {
  try {
    const [providersRes, agentsRes] = await Promise.all([
      listModelProviders(),
      agentAPI.getAgents()
    ])
    providers.value = providersRes || []
    // 后端返回格式: [...]
    allAgents.value = agentsRes || []
  } catch (e) {
    console.error('Failed to load data', e)
  }
}

// Save handlers
const handleSave = async (shouldExit = true) => {
  saving.value = true
  try {
    setIMChannelsOnForm()
    store.prepareForSave()
    const plainData = JSON.parse(JSON.stringify(store.formData))
    await new Promise((resolve) => {
      emit('save', plainData, shouldExit, () => resolve())
    })
  } catch (e) {
    console.error('handleSave error', e)
  } finally {
    saving.value = false
  }
}

const handleReturn = () => {
  emit('update:visible', false)
}

// Helpers for Selects
const getSelectValue = (val) => {
  if (val === null) return 'auto'
  return val ? 'enabled' : 'disabled'
}

const setSelectValue = (field, val) => {
  if (val === 'auto') store.formData[field] = null
  else if (val === 'enabled') store.formData[field] = true
  else store.formData[field] = false
}

// Sub-agent Logic
const filteredAgents = computed(() => {
  return allAgents.value.filter(a => a.id !== store.formData.id)
})

const isSubAgentSelected = (id) => {
  return store.formData.availableSubAgentIds?.includes(id) || false
}

const toggleSubAgent = (id, checked) => {
  const currentIds = [...(store.formData.availableSubAgentIds || [])]
  if (checked) {
    if (!currentIds.includes(id)) currentIds.push(id)
  } else {
    const index = currentIds.indexOf(id)
    if (index > -1) currentIds.splice(index, 1)
  }
  store.formData.availableSubAgentIds = currentIds
}

const selectAllSubAgents = () => {
  const allAgentIds = filteredAgents.value.map(agent => agent.id)
  store.formData.availableSubAgentIds = [...new Set([...(store.formData.availableSubAgentIds || []), ...allAgentIds])]
}

// Workflow expansion
const expandedWorkflows = reactive(new Set())
const toggleWorkflow = (id) => {
  if (expandedWorkflows.has(id)) {
    expandedWorkflows.delete(id)
  } else {
    expandedWorkflows.add(id)
  }
}
const isWorkflowExpanded = (id) => expandedWorkflows.has(id)

const handleAddWorkflow = () => {
  store.addWorkflowPair()
  setTimeout(() => {
    const newWorkflow = store.workflowPairs[store.workflowPairs.length - 1]
    if (newWorkflow?.id) {
      expandedWorkflows.add(newWorkflow.id)
    }
  }, 0)
}

// Optimization
const showOptimizeModal = ref(false)
const isOptimizing = ref(false)
const optimizationGoal = ref('')
const optimizedResult = ref('')
const optimizeAbortController = ref(null)

const handleOptimizeStart = async () => {
  if (isOptimizing.value) return
  isOptimizing.value = true
  const controller = new AbortController()
  optimizeAbortController.value = controller
  try {
    const result = await agentAPI.systemPromptOptimize({
      original_prompt: store.formData.systemPrefix,
      optimization_goal: optimizationGoal.value
    }, {
      signal: controller.signal
    })
    if (result?.optimized_prompt) {
      optimizedResult.value = result.optimized_prompt
    }
  } catch (e) {
    if (controller.signal.aborted || e?.name === 'AbortError') {
      return
    }
    console.error('Optimization failed:', e)
  } finally {
    if (optimizeAbortController.value === controller) {
      optimizeAbortController.value = null
    }
    isOptimizing.value = false
  }
}

const handleOptimizeCancel = () => {
  if (optimizeAbortController.value) {
    optimizeAbortController.value.abort()
    optimizeAbortController.value = null
  }
  isOptimizing.value = false
  showOptimizeModal.value = false
  optimizationGoal.value = ''
  optimizedResult.value = ''
}

const handleResetOptimization = () => {
  optimizedResult.value = ''
}

const handleApplyOptimization = () => {
  if (optimizedResult.value) {
    store.formData.systemPrefix = optimizedResult.value
    handleOptimizeCancel()
  }
}

onBeforeUnmount(() => {
  if (optimizeAbortController.value) {
    optimizeAbortController.value.abort()
    optimizeAbortController.value = null
  }
})

// Tools logic
const searchQueries = reactive({ tools: '', skills: '', knowledgeBases: '' })
const selectedGroupSource = ref('')

const REQUIRED_TOOLS_FOR_SKILLS = [
  'file_read', 'execute_python_code', 'execute_javascript_code', 
  'execute_shell_command', 'file_write', 'file_update', 'load_skill'
]

const isRequiredTool = (toolName) => {
  const hasSkills = store.formData.availableSkills?.length > 0
  const isRequiredForIM = hasEnabledIMChannel.value && IM_TOOLS.includes(toolName)
  return isRequiredForIM || (hasSkills && REQUIRED_TOOLS_FOR_SKILLS.includes(toolName))
}

const handleToolToggle = (toolName) => {
  if (isRequiredTool(toolName)) {
    return
  }

  if (IM_TOOLS.includes(toolName) && !hasEnabledIMChannel.value) {
    toast.error(t('agentEdit.enableImFirst'))
    return
  }

  store.toggleTool(toolName)
}

const filteredTools = computed(() => {
  if (!searchQueries.tools) return props.tools
  const query = searchQueries.tools.toLowerCase()
  return props.tools.filter(tool => 
    tool.name.toLowerCase().includes(query) || 
    (tool.description && tool.description.toLowerCase().includes(query))
  )
})

const groupedTools = computed(() => {
  const groups = {}
  filteredTools.value.forEach(tool => {
    const source = tool.source || t('agentEdit.unknownSource')
    if (!groups[source]) {
      groups[source] = { source, tools: [] }
    }
    groups[source].tools.push(tool)
  })
  return Object.values(groups).sort((a, b) => a.source.localeCompare(b.source))
})

const displayedTools = computed(() => {
  if (!selectedGroupSource.value) return []
  const group = groupedTools.value.find(g => g.source === selectedGroupSource.value)
  return group ? group.tools : []
})

// Select/Deselect all tools in current group
const selectAllToolsInGroup = () => {
  const currentTools = displayedTools.value
  currentTools.forEach(tool => {
    if (!isRequiredTool(tool.name) && (!IM_TOOLS.includes(tool.name) || hasEnabledIMChannel.value) && !store.formData.availableTools.includes(tool.name)) {
      store.formData.availableTools.push(tool.name)
    }
  })
}

const deselectAllToolsInGroup = () => {
  const currentTools = displayedTools.value
  currentTools.forEach(tool => {
    if (!isRequiredTool(tool.name)) {
      const index = store.formData.availableTools.indexOf(tool.name)
      if (index > -1) {
        store.formData.availableTools.splice(index, 1)
      }
    }
  })
}

watch(groupedTools, (newGroups) => {
  if (newGroups.length > 0) {
    if (!selectedGroupSource.value || !newGroups.find(g => g.source === selectedGroupSource.value)) {
      selectedGroupSource.value = newGroups[0].source
    }
  } else {
    selectedGroupSource.value = ''
  }
}, { immediate: true })

watch(() => store.formData.availableSkills, (newSkills) => {
  if (newSkills?.length > 0) {
    REQUIRED_TOOLS_FOR_SKILLS.forEach(toolName => {
      if (!store.formData.availableTools.includes(toolName)) {
        store.formData.availableTools.push(toolName)
      }
    })
  }
}, { deep: true })

const getToolSourceLabel = (source) => {
  let displaySource = source
  if (source.startsWith('MCP Server: ')) {
    displaySource = getMcpServerLabel(source.replace('MCP Server: ', ''), t)
  } else if (source.startsWith('Built-in MCP: ')) {
    displaySource = getMcpServerLabel(source.replace('Built-in MCP: ', ''), t)
  } else if (source.startsWith('内置MCP: ')) {
    displaySource = getMcpServerLabel(source.replace('内置MCP: ', ''), t)
  }
  const sourceMapping = {
    '基础工具': 'tools.source.basic',
    'Basic Tools': 'tools.source.basic',
    '内置工具': 'tools.source.builtin',
    'Built-in Tools': 'tools.source.builtin',
    '系统工具': 'tools.source.system',
    'System Tools': 'tools.source.system'
  }
  const translationKey = sourceMapping[displaySource]
  return translationKey ? t(translationKey) : displaySource
}

const getGroupIcon = (source) => {
  if (source.includes('MCP')) return Server
  if (['基础工具', '内置工具', '系统工具', 'Basic Tools', 'Built-in Tools', 'System Tools'].includes(source)) return Code
  return Wrench
}

// Skills logic
// 优先使用API加载的技能列表（包含need_update字段）
// 如果API加载失败，使用props.skills（但不会有need_update字段）
const skillsList = computed(() => {
  console.log('[SkillSync] skillsList computed, agentSkills:', agentSkills.value.length, 'props.skills:', props.skills?.length)
  // 如果有agent id，优先使用API加载的技能列表
  if (props.agent?.id && agentSkills.value.length > 0) {
    console.log('[SkillSync] Using agentSkills from API')
    return agentSkills.value
  }
  // 否则使用props.skills（父组件传入的）
  console.log('[SkillSync] Using props.skills')
  return props.skills || []
})

const filteredSkills = computed(() => {
  if (!searchQueries.skills) return skillsList.value
  const query = searchQueries.skills.toLowerCase()
  return skillsList.value.filter(skill => {
    const name = skill.name || skill
    const desc = skill.description || ''
    return name.toLowerCase().includes(query) || desc.toLowerCase().includes(query)
  })
})

// Selected skills for display as tags
const selectedSkills = computed(() => {
  const selected = store.formData.availableSkills || []
  return selected.map(skillName => {
    const skill = skillsList.value.find(s => (s.name || s) === skillName)
    return skill || skillName
  })
})

// Select/Deselect all skills
const selectAllSkills = () => {
  filteredSkills.value.forEach(skill => {
    const skillName = skill.name || skill
    if (!store.formData.availableSkills?.includes(skillName)) {
      store.toggleSkill(skillName)
    }
  })
}

const deselectAllSkills = () => {
  const currentSkills = [...(store.formData.availableSkills || [])]
  currentSkills.forEach(skillName => {
    store.toggleSkill(skillName)
  })
}

// Knowledge Bases logic
const filteredKnowledgeBases = computed(() => {
  if (!searchQueries.knowledgeBases) return props.knowledgeBases
  const query = searchQueries.knowledgeBases.toLowerCase()
  return props.knowledgeBases.filter(kb => 
    kb.name.toLowerCase().includes(query) || 
    (kb.intro && kb.intro.toLowerCase().includes(query))
  )
})

const toggleKnowledgeBase = (id) => {
  if (!Array.isArray(store.formData.availableKnowledgeBases)) {
    store.formData.availableKnowledgeBases = []
  }
  const index = store.formData.availableKnowledgeBases.indexOf(id)
  if (index === -1) {
    store.formData.availableKnowledgeBases.push(id)
  } else {
    store.formData.availableKnowledgeBases.splice(index, 1)
  }
}

const selectAllKnowledgeBases = () => {
  filteredKnowledgeBases.value.forEach(kb => {
    if (!store.formData.availableKnowledgeBases?.includes(kb.id)) {
      toggleKnowledgeBase(kb.id)
    }
  })
}

const deselectAllKnowledgeBases = () => {
  const currentKBs = [...(store.formData.availableKnowledgeBases || [])]
  currentKBs.forEach(id => {
    toggleKnowledgeBase(id)
  })
}
</script>

<style scoped>
.scroll-mt-6 {
  scroll-margin-top: 1.5rem;
}
</style>
